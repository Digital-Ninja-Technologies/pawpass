-- The product is called OurPawPass. Notification and message texts written inside database functions said
-- "PawPass" (for example "PawPass decided your report", "The PawPass team reviews it within 48 hours").
-- This rewrites those functions with the new name. Replacing only whole words makes it safe to run again, and
-- "a PawPass" becomes "an OurPawPass". Notifications that already exist keep the words they were made with.

do $$
declare
  f record;
  def text;
  n integer := 0;
begin
  for f in
    select q.oid
      from (
        select p.oid
          from pg_proc p
          join pg_namespace ns on ns.oid = p.pronamespace
         where ns.nspname in ('public', 'private') and p.prokind = 'f'
        offset 0
      ) q
     where pg_get_functiondef(q.oid) ~ '\mPawPass\M'
  loop
    def := pg_get_functiondef(f.oid);
    def := regexp_replace(def, '\mA PawPass\M', 'An OurPawPass', 'g');
    def := regexp_replace(def, '\ma PawPass\M', 'an OurPawPass', 'g');
    def := regexp_replace(def, '\mPawPass\M', 'OurPawPass', 'g');
    execute def;
    n := n + 1;
  end loop;
  raise notice 'rewrote % functions', n;
end $$;
