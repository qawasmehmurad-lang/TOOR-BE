alter table public.ad_video_settings
  add column if not exists link_url text not null default '#';

alter table public.ad_video_settings
  drop constraint if exists ad_video_settings_link_url_valid;

alter table public.ad_video_settings
  add constraint ad_video_settings_link_url_valid
  check (
    link_url = '#'
    or link_url ~* '^https?://'
  );
