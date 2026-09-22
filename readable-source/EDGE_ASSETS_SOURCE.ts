import { withSupabase } from "jsr:@supabase/server@1.5.3";

const BUCKET = "jpp1e-assets";
const MAX_FILE_SIZE = 10 * 1024 * 1024;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type AssetType = "character" | "token" | "map" | "mapsheet" | "handout";
type AuthType = "owner" | "player";

type AuthResult = {
  roomCode: string;
  characterId: string | null;
  isOwner: boolean;
  state: any;
};

function json(data: unknown, status = 200) {
  return Response.json(data, { status, headers: corsHeaders });
}

function cleanPart(value: string) {
  return value.trim().replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 120);
}

function extensionFromMime(mime: string) {
  const normalized = mime.toLowerCase();
  if (normalized === "image/jpeg") return "jpg";
  if (normalized === "image/png") return "png";
  if (normalized === "image/webp") return "webp";
  if (normalized === "image/gif") return "gif";
  if (normalized === "image/avif") return "avif";
  return "img";
}

function assetFolder(assetType: AssetType) {
  if (assetType === "character") return "characters";
  if (assetType === "token") return "tokens";
  if (assetType === "map") return "maps";
  if (assetType === "mapsheet") return "mapsheets";
  return "handouts";
}

function assetTypeFromFolder(folder: string): AssetType | null {
  if (folder === "characters") return "character";
  if (folder === "tokens") return "token";
  if (folder === "maps") return "map";
  if (folder === "mapsheets") return "mapsheet";
  if (folder === "handouts") return "handout";
  return null;
}

function parseStoredPath(path: string) {
  const parts = path.split("/");
  if (parts.length !== 5 || parts[0] !== "rooms" || path.length > 512 ||
      !parts.slice(1, 4).every(part => /^[a-zA-Z0-9_-]+$/.test(part)) ||
      !/^[a-zA-Z0-9_-]+\.[a-zA-Z0-9]+$/.test(parts[4])) return null;
  const assetType = assetTypeFromFolder(parts[2]);
  if (!assetType) return null;
  return {
    roomCode: parts[1],
    identifier: parts[3],
    assetType,
  };
}

async function authorize(
  ctx: any,
  values: { authType: AuthType; roomCode?: string; ownerSecret?: string; inviteCode?: string },
): Promise<AuthResult> {
  const { authType, roomCode, ownerSecret, inviteCode } = values;

  if (authType === "owner") {
    if (!roomCode || !ownerSecret) throw new Error("OWNER_AUTH_REQUIRED");
    const normalizedRoomCode = roomCode.trim().toUpperCase();
    const { data, error } = await ctx.supabaseAdmin.rpc("jpp1e_load_room", {
      p_room_code: normalizedRoomCode,
      p_owner_secret: ownerSecret,
    });
    if (error) throw new Error(["PGRST202","PGRST203","42883"].includes(error.code) ? "SERVER_RPC_MISSING" : "AUTH_FAILED");
    const room = Array.isArray(data) ? data[0] : data;
    if (!room?.room_code) throw new Error("AUTH_FAILED");
    return {
      roomCode: String(room.room_code).trim().toUpperCase(),
      characterId: null,
      isOwner: true,
      state: room.state || {},
    };
  }

  if (authType === "player") {
    if (!inviteCode) throw new Error("PLAYER_AUTH_REQUIRED");
    const { data, error } = await ctx.supabaseAdmin.rpc("jpp1e_join_player", {
      p_invite_code: inviteCode,
    });
    if (error) throw new Error(["PGRST202","PGRST203","42883"].includes(error.code) ? "SERVER_RPC_MISSING" : "AUTH_FAILED");
    const joined = Array.isArray(data) ? data[0] : data;
    if (!joined?.room_code || !joined?.character_id) throw new Error("AUTH_FAILED");
    return {
      roomCode: String(joined.room_code).trim().toUpperCase(),
      characterId: String(joined.character_id),
      isOwner: false,
      state: joined.state || {},
    };
  }

  throw new Error("AUTH_TYPE_INVALID");
}

function checkAssetType(value: unknown): AssetType {
  if (["character", "token", "map", "mapsheet", "handout"].includes(String(value))) {
    return value as AssetType;
  }
  throw new Error("ASSET_TYPE_INVALID");
}

function playerMaySeeHandoutPath(auth: AuthResult, path: string) {
  const handouts = Array.isArray(auth.state?.handouts) ? auth.state.handouts : [];
  return handouts.some((h: any) => {
    const ref = String(h?.image || h?.imageData || h?.imageUrl || "");
    return ref === path || ref === `storage:${path}`;
  });
}

function playerMaySeePublicImagePath(auth: AuthResult, path: string) {
  // Only the server-filtered state from authorize(), never request-supplied state.
  const matches = (ref: unknown) => ref === `storage:${path}`;
  const rows = (value: unknown): any[] => Array.isArray(value) ? value : [];
  // Scene portraits resolve characterId through these same public characters.
  return rows(auth.state?.characters).some(c => matches(c?.image)) ||
    rows(auth.state?.tokens).some(t => matches(t?.customImage) || matches(t?.image)) ||
    rows(auth.state?.messages).some(m => matches(m?.seal));
}

function authErrorResponse(error: unknown, reply = json) {
  const message = error instanceof Error ? error.message : "";
  if(message === "SERVER_RPC_MISSING") return reply({ok:false, code:message, error:"서버 SQL 설치 또는 업데이트가 필요합니다."},503);
  if (["OWNER_AUTH_REQUIRED", "PLAYER_AUTH_REQUIRED", "AUTH_FAILED"].includes(message)) {
    return reply({ ok: false, error: "권한을 확인할 수 없습니다." }, 403);
  }
  if (["AUTH_TYPE_INVALID", "ASSET_TYPE_INVALID"].includes(message)) {
    return reply({ ok: false, error: "잘못된 요청입니다." }, 400);
  }
  
  return reply({ ok: false, error: "이미지 처리 중 오류가 발생했습니다." }, 500);
}

console.info("jpp1e-assets stage3 started");

export default {
  fetch: withSupabase(
    { auth: ["publishable", "secret"] },
    async (req, ctx) => {
      const traceId = crypto.randomUUID();
      const reply = (data: any, status = 200) => {
        const code = data.code || (status === 403 ? "ASSET_FORBIDDEN" : status === 400 ? "ASSET_INVALID" : status >= 500 ? "ASSET_SERVER_ERROR" : "ASSET_REQUEST_FAILED");
        if(data.ok === false) console.error("asset failure", {traceId, code, status});
        return json(data.ok === false ? {...data, code, traceId} : data, status);
      };
      if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
      if (req.method !== "POST") return reply({ ok: false, error: "POST 요청만 사용할 수 있습니다." }, 405);

      try {
        const contentType = req.headers.get("content-type") || "";

        if (contentType.includes("multipart/form-data")) {
          const form = await req.formData();
          const action = String(form.get("action") || "");
          if (action !== "upload") return reply({ ok: false, error: "알 수 없는 업로드 요청입니다." }, 400);

          const authType = String(form.get("authType") || "") as AuthType;
          const auth = await authorize(ctx, {
            authType,
            roomCode: String(form.get("roomCode") || ""),
            ownerSecret: String(form.get("ownerSecret") || ""),
            inviteCode: String(form.get("inviteCode") || ""),
          });
          const assetType = checkAssetType(String(form.get("assetType") || ""));
          const requestedId = String(form.get("characterId") || "").trim();
          const file = form.get("file");

          if (!(file instanceof File)) return reply({ ok: false, error: "이미지 파일이 없습니다." }, 400);
          if (!file.type.startsWith("image/")) return reply({ ok: false, error: "이미지 파일만 업로드할 수 있습니다." }, 400);
          if (file.size <= 0 || file.size > MAX_FILE_SIZE) return reply({ ok: false, error: "이미지는 10MB 이하여야 합니다." }, 400);

          if (!auth.isOwner && assetType !== "character" && assetType !== "token") {
            return reply({ ok: false, error: "플레이어는 이 종류의 이미지를 업로드할 수 없습니다." }, 403);
          }

          let identifier = requestedId;
          if (!auth.isOwner) {
            identifier = auth.characterId || "";
            if (requestedId && requestedId !== identifier) {
              return reply({ ok: false, error: "다른 캐릭터의 이미지는 변경할 수 없습니다." }, 403);
            }
          } else {
            if (assetType === "map") identifier = "__map__";
            if (assetType === "mapsheet") identifier = "__mapsheet__";
          }

          if ((assetType === "character" || assetType === "token" || assetType === "handout") && !identifier) {
            return reply({ ok: false, error: "이미지 대상을 확인할 수 없습니다." }, 400);
          }

          if (assetType === "character" || assetType === "token") {
            const existingCharacter = Array.isArray(auth.state?.characters) &&
              auth.state.characters.some((c: any) => c?.id === identifier);
            // Only a credential-verified GM may upload before the new room state is saved.
            // Linked tokens use a character ID; standalone tokens use token- + uid("t").
            const newOwnerTarget = auth.isOwner && (
              (assetType === "character" && /^c_[0-9]+_[a-z0-9]{1,5}$/.test(identifier)) ||
              (assetType === "token" && /^token-t_[0-9]+_[a-z0-9]{1,5}$/.test(identifier))
            );
            if (!existingCharacter && !newOwnerTarget) {
              return reply({ ok: false, error: "캐릭터 또는 토큰을 확인할 수 없습니다." }, 400);
            }
          }

          const safeRoom = cleanPart(auth.roomCode);
          const safeIdentifier = cleanPart(identifier || "asset");
          const ext = extensionFromMime(file.type);
          const filename = `${crypto.randomUUID()}.${ext}`;
          const path = `rooms/${safeRoom}/${assetFolder(assetType)}/${safeIdentifier}/${filename}`;

          const { error: uploadError } = await ctx.supabaseAdmin.storage.from(BUCKET).upload(path, file, {
            contentType: file.type,
            cacheControl: "3600",
            upsert: false,
          });
          if (uploadError) {
            
            return reply({ ok: false, code: "STORAGE_UPLOAD_FAILED", error: "이미지를 Storage에 저장하지 못했습니다." }, 500);
          }

          return reply({ ok: true, path, assetType, characterId: identifier });
        }

        const body = await req.json();
        const action = String(body?.action || "");
        const authType = String(body?.authType || "") as AuthType;
        const auth = await authorize(ctx, {
          authType,
          roomCode: body?.roomCode,
          ownerSecret: body?.ownerSecret,
          inviteCode: body?.inviteCode,
        });

        if (action === "sign") {
          const path = String(body?.path || "");
          const parsed = parseStoredPath(path);
          if (!parsed) return reply({ ok: false, error: "허용되지 않은 이미지 경로입니다." }, 400);
          if (parsed.roomCode.toUpperCase() !== auth.roomCode.toUpperCase()) {
            return reply({ ok: false, error: "다른 방의 이미지는 볼 수 없습니다." }, 403);
          }

          if (!auth.isOwner && (parsed.assetType === "map" || parsed.assetType === "mapsheet")) {
            const layout = auth.state?.layout || {};
            const ref = parsed.assetType === "map" ? layout.boardImage : layout.mapSheetImage;
            if((parsed.assetType === "map" && layout.mapVisible === false) || ref !== 'storage:' + path) {
              return reply({ok:false, code:"MAP_NOT_PUBLIC", error:"현재 공개된 맵만 볼 수 있습니다."},403);
            }
          }
          if (parsed.assetType === "handout" && !auth.isOwner && !playerMaySeeHandoutPath(auth, path)) {
            return reply({ ok: false, error: "이 핸드아웃 이미지를 볼 권한이 없습니다." }, 403);
          }

          if (!auth.isOwner && (parsed.assetType === "character" || parsed.assetType === "token") &&
              parsed.identifier !== auth.characterId && !playerMaySeePublicImagePath(auth, path)) {
            return reply({ ok: false, error: "다른 캐릭터의 이미지는 볼 수 없습니다." }, 403);
          }

          const { data, error } = await ctx.supabaseAdmin.storage.from(BUCKET).createSignedUrl(path, 60 * 60);
          if (error || !data?.signedUrl) {
            
            return reply({ ok: false, code: "STORAGE_SIGN_FAILED", error: "이미지를 불러오지 못했습니다." }, 500);
          }
          return reply({ ok: true, signedUrl: data.signedUrl, expiresIn: 3600 });
        }

        if (action === "delete") {
          const path = String(body?.path || "");
          const parsed = parseStoredPath(path);
          if (!parsed) return reply({ ok: false, error: "허용되지 않은 이미지 경로입니다." }, 400);
          if (parsed.roomCode.toUpperCase() !== auth.roomCode.toUpperCase()) {
            return reply({ ok: false, error: "다른 방의 이미지는 삭제할 수 없습니다." }, 403);
          }

          if (!auth.isOwner) {
            if ((parsed.assetType !== "character" && parsed.assetType !== "token") || parsed.identifier !== auth.characterId) {
              return reply({ ok: false, error: "이 이미지는 삭제할 수 없습니다." }, 403);
            }
          }

          const { error } = await ctx.supabaseAdmin.storage.from(BUCKET).remove([path]);
          if (error) {
            
            return reply({ ok: false, code: "STORAGE_DELETE_FAILED", error: "이미지를 삭제하지 못했습니다." }, 500);
          }
          return reply({ ok: true });
        }

        return reply({ ok: false, error: "알 수 없는 요청입니다." }, 400);
      } catch (error) {
        return authErrorResponse(error, reply);
      }
    },
  ),
};
