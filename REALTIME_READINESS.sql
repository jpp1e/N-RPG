select to_regclass('realtime.messages') is not null as messages_ready,
  to_regprocedure('realtime.send(jsonb,text,text,boolean)') is not null as send_ready,
  to_regprocedure('realtime.topic()') is not null as topic_present,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='realtime') as realtime_function_count;
