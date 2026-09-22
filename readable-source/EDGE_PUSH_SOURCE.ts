import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import webpush from "npm:web-push@3.6.7";

const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY") || "";
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY") || "";
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") || "";
let vapidReady = false;
try {
  if (VAPID_PUBLIC_KEY && VAPID_PRIVATE_KEY && /^(mailto:|https:\/\/)/.test(VAPID_SUBJECT)) {
    webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);
    vapidReady = true;
  }
} catch { /* Fail closed without logging secret values. */ }

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
function codeIdFromInvite(inviteCode: string) { return (inviteCode || "").trim().split(".")[0]?.toUpperCase() || ""; }
function cleanNotificationTypes(raw: unknown) {
  const allowed = new Set(["chat", "desc", "system"]);
  if (!Array.isArray(raw)) return ["chat"];
  const clean = [...new Set(raw.map(String).filter(x => allowed.has(x)))];
  return clean.length ? clean : ["chat"];
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const body = await req.json();
    const action = String(body?.action || "");
    if (!vapidReady) return json({ error: "push_config_required" }, 503);
    if (action === "config") return json({ publicKey: VAPID_PUBLIC_KEY });

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) return json({ error: "server_config" }, 500);
    const db = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

    let actor: any = null;
    if (body?.inviteCode) {
      const inviteCode = String(body.inviteCode);
      const { data: joined, error: joinErr } = await db.rpc("jpp1e_join_player", { p_invite_code: inviteCode });
      if (joinErr) throw joinErr;
      const row = Array.isArray(joined) ? joined[0] : joined;
      if (!row?.room_code) return json({ error: "unauthorized" }, 403);
      const { data: room } = await db.from("jpp1e_rooms").select("id,room_code").eq("room_code", row.room_code).maybeSingle();
      const { data: invite } = await db.from("jpp1e_room_invites").select("id,character_id,character_name").eq("room_id", room?.id).eq("code_id", codeIdFromInvite(inviteCode)).eq("active", true).eq("kind", "reconnect").is("revoked_at", null).maybeSingle();
      if (!room?.id || !invite?.id) return json({ error: "unauthorized" }, 403);
      actor = { roomId: room.id, roomCode: room.room_code, role: "player", inviteId: invite.id, characterId: invite.character_id, characterName: invite.character_name };
    } else if (body?.roomCode && body?.ownerSecret) {
      const { data: loaded, error: loadErr } = await db.rpc("jpp1e_load_room", { p_room_code: String(body.roomCode), p_owner_secret: String(body.ownerSecret) });
      if (loadErr) throw loadErr;
      const row = Array.isArray(loaded) ? loaded[0] : loaded;
      if (!row?.room_id) return json({ error: "unauthorized" }, 403);
      actor = { roomId: row.room_id, roomCode: row.room_code, role: "gm", inviteId: null, characterId: null, characterName: "GM" };
    } else return json({ error: "missing_credentials" }, 400);

    if (action === "register") {
      const sub = body?.subscription;
      const endpoint = String(sub?.endpoint || "");
      const p256dh = String(sub?.keys?.p256dh || "");
      const auth = String(sub?.keys?.auth || "");
      if (!endpoint || !p256dh || !auth) return json({ error: "invalid_subscription" }, 400);
      const notificationTypes = cleanNotificationTypes(body?.notificationTypes);
      const { error } = await db.rpc("jpp1e_push_manage_subscription", {
        p_action: "register", p_invite_code: body?.inviteCode || null,
        p_room_code: body?.roomCode || null, p_owner_secret: body?.ownerSecret || null,
        p_subscription: sub, p_show_preview: !!body?.showPreview, p_notification_types: notificationTypes,
      });
      if (error) throw error;
      return json({ ok: true });
    }

    if (action === "unregister") {
      const endpoint = String(body?.endpoint || "");
      if (!endpoint) return json({ error: "invalid_endpoint" }, 400);
      const { error } = await db.rpc("jpp1e_push_manage_subscription", {
        p_action: "unregister", p_invite_code: body?.inviteCode || null,
        p_room_code: body?.roomCode || null, p_owner_secret: body?.ownerSecret || null,
        p_subscription: { endpoint },
      });
      if (error) throw error;
      return json({ ok: true });
    }

    const { data: subs, error: subErr } = await db.from("jpp1e_push_subscriptions").select("id,invite_id,role,endpoint,p256dh,auth,show_preview,notification_types").eq("room_id", actor.roomId);
    if (subErr) throw subErr;

    // A target selected before revoke/reissue must still exist and be authorized
    // immediately before delivery. Already in-flight web-push cannot be recalled.
    async function deliveryAllowed(s: any) {
      if (actor.role === "player") {
        const { data, error } = await db.rpc("jpp1e_join_player", { p_invite_code: String(body.inviteCode) });
        if (error || !(Array.isArray(data) ? data[0] : data)?.room_code) return false;
      }
      const { data: current, error } = await db.from("jpp1e_push_subscriptions")
        .select("id,invite_id,role").eq("id", s.id).eq("room_id", actor.roomId).maybeSingle();
      if (error || !current || current.invite_id !== s.invite_id || current.role !== s.role) return false;
      if (current.role === "gm") return true;
      const { data: invite, error: inviteError } = await db.from("jpp1e_room_invites")
        .select("id").eq("id", current.invite_id).eq("room_id", actor.roomId)
        .eq("kind", "reconnect").eq("active", true).is("revoked_at", null).maybeSingle();
      return !inviteError && !!invite;
    }

    if (action === "test") {
      const targets = (subs || []).filter((s: any) => actor.role === "player" ? s.invite_id === actor.inviteId : s.role === "gm");
      let sent = 0, failed = 0;
      for (const s of targets) {
        if (!await deliveryAllowed(s)) continue;
        try {
          await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify({ title: "Jpp1e TRPG", body: "🔔 알림 테스트가 정상적으로 도착했습니다.", tag: `jpp1e-test-${actor.roomCode}`, url: "./" }), { TTL: 120 });
          sent++;
        } catch (err: any) {
          failed++;
          const status = Number(err?.statusCode || err?.status || 0);
          if (status === 404 || status === 410) await db.from("jpp1e_push_subscriptions").delete().eq("id", s.id);
          else console.error("push test failed", status, err?.message || err);
        }
      }
      return json({ ok: true, sent, failed });
    }

    if (action === "send_message") {
      const text = String(body?.text || "").trim().slice(0, 500);
      if (!text) return json({ error: "empty_message" }, 400);
      const messageKind = ["chat", "desc", "system"].includes(String(body?.messageKind || "")) ? String(body.messageKind) : "chat";
      const displayName = actor.role === "player" ? actor.characterName : (String(body?.senderName || "GM").trim().slice(0, 60) || "GM");
      const targets = (subs || []).filter((s: any) => {
        const notSender = actor.role === "player" ? s.invite_id !== actor.inviteId : s.role !== "gm";
        const types = cleanNotificationTypes(s.notification_types);
        return notSender && types.includes(messageKind);
      });
      let sent = 0, failed = 0;
      for (const s of targets) {
        if (!await deliveryAllowed(s)) continue;
        const reveal = !!s.show_preview;
        const payload = JSON.stringify({ title: reveal ? `${displayName} · Jpp1e TRPG` : "Jpp1e TRPG", body: reveal ? text.slice(0, 120) : "새로운 메시지가 도착했습니다.", tag: `jpp1e-${actor.roomCode}`, url: "./", kind: messageKind });
        try {
          await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 300 });
          sent++;
        } catch (err: any) {
          failed++;
          const status = Number(err?.statusCode || err?.status || 0);
          if (status === 404 || status === 410) await db.from("jpp1e_push_subscriptions").delete().eq("id", s.id);
          else console.error("push send failed", status, err?.message || err);
        }
      }
      return json({ ok: true, sent, failed });
    }

    return json({ error: "unknown_action" }, 400);
  } catch (err: any) {
    console.error("jpp1e-push error", err?.code || "request_failed");
    return json({ error: "server_error" }, 500);
  }
});
