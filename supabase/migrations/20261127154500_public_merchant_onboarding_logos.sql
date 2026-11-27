insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('merchant-logos','merchant-logos',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "merchant logos owner upload" on storage.objects;
create policy "merchant logos owner upload" on storage.objects
for insert to authenticated
with check (
  bucket_id='merchant-logos'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);
