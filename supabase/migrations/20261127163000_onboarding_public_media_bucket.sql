insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('onboarding-public-media','onboarding-public-media',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "onboarding public media owner upload" on storage.objects;
create policy "onboarding public media owner upload" on storage.objects
for insert to authenticated
with check (
  bucket_id='onboarding-public-media'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);
