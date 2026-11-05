-- Storage buckets, storage access policies and realtime publication.
--
-- Path conventions (the first folder decides who owns the file):
--   avatars/{user_id}/...
--   pet-photos/{user_id}/{pet_id}/...
--   post-media/{user_id}/...
--   health-attachments/{user_id}/{pet_id}/...
--   partner-documents/{user_id}/...          (government ID, CAC, licences: private)
--   dispute-evidence/{user_id}/...
--   chat-attachments/{conversation_id}/...

-- Casts a path segment to uuid, or null if it is not one.
create function private.safe_uuid(v text) returns uuid
language plpgsql immutable
set search_path = ''
as $$
begin
  return v::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;
revoke all on function private.safe_uuid(text) from public, anon;
grant execute on function private.safe_uuid(text) to authenticated, service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars',            'avatars',            false, 5242880,  array['image/jpeg', 'image/png', 'image/webp']),
  ('pet-photos',         'pet-photos',         false, 10485760, array['image/jpeg', 'image/png', 'image/webp']),
  ('post-media',         'post-media',         false, 10485760, array['image/jpeg', 'image/png', 'image/webp']),
  ('health-attachments', 'health-attachments', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('partner-documents',  'partner-documents',  false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('dispute-evidence',   'dispute-evidence',   false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('chat-attachments',   'chat-attachments',   false, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Owner folder buckets: write only into your own folder.
-- ---------------------------------------------------------------------------
create policy "write into own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('avatars', 'post-media', 'partner-documents', 'dispute-evidence')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "update own folder files" on storage.objects
  for update to authenticated
  using (
    bucket_id in ('avatars', 'post-media', 'partner-documents', 'dispute-evidence')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "delete own folder files" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('avatars', 'post-media', 'partner-documents', 'dispute-evidence', 'pet-photos', 'health-attachments')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Avatars and post media are visible to signed in users. Paths are unguessable;
-- post visibility (followers, nearby) is enforced on the posts table, not the file.
create policy "signed in users read avatars and post media" on storage.objects
  for select to authenticated
  using (bucket_id in ('avatars', 'post-media'));

-- Partner documents contain government ID: owner and the verifications team only.
create policy "read partner documents" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'partner-documents'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or private.is_staff(array['verifications'])
    )
  );

create policy "read dispute evidence" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'dispute-evidence'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or private.is_staff(array['payouts_disputes', 'read_only'])
    )
  );

-- ---------------------------------------------------------------------------
-- Pet photos: {user_id}/{pet_id}/file. Visible to anyone who may see the pet.
-- ---------------------------------------------------------------------------
create policy "upload pet photo for own pet" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'pet-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and private.owns_pet(private.safe_uuid((storage.foldername(name))[2]))
  );

create policy "read pet photo if pet is visible" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'pet-photos'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or private.can_view_pet(private.safe_uuid((storage.foldername(name))[2]))
    )
  );

-- ---------------------------------------------------------------------------
-- Health attachments: {user_id}/{pet_id}/file.
-- The owner, or a partner with a live share, can read. A partner with a live
-- "write" share can upload into their own folder for that pet.
-- ---------------------------------------------------------------------------
create policy "upload health attachment" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'health-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (
      private.owns_pet(private.safe_uuid((storage.foldername(name))[2]))
      or private.has_active_share(private.safe_uuid((storage.foldername(name))[2]), 'write')
    )
  );

create policy "read health attachment" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'health-attachments'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or private.owns_pet(private.safe_uuid((storage.foldername(name))[2]))
      or private.has_active_share(private.safe_uuid((storage.foldername(name))[2]), 'health')
    )
  );

-- ---------------------------------------------------------------------------
-- Chat attachments: {conversation_id}/file. Members only.
-- ---------------------------------------------------------------------------
create policy "members upload chat attachments" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and private.in_conversation(private.safe_uuid((storage.foldername(name))[1]))
  );

create policy "members read chat attachments" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and private.in_conversation(private.safe_uuid((storage.foldername(name))[1]))
  );

-- ---------------------------------------------------------------------------
-- Realtime. Postgres changes respect the RLS policies above.
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages, public.lost_alerts, public.sightings;
  end if;
end;
$$;
