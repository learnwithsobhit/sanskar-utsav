# Video encoding for Sanskar Utsav

Guest uploads are played in the Flutter app with progressive download (`video_player`). Smaller, web-friendly files start faster and stall less.

## Recommended settings

| Topic | Recommendation |
|--------|------------------|
| Container | **MP4** (`.mp4`) |
| Video codec | **H.264** (AVC), Main or High profile |
| Audio codec | **AAC** |
| Resolution | **720p** or **1080p** max; avoid 4K for phone uploads |
| Bitrate | **2–6 Mbps** for 1080p, **1–3 Mbps** for 720p (adjust for motion) |
| Fast start | **Moov atom at the beginning** of the file (`ffmpeg -movflags +faststart`) so playback can begin before the full file is downloaded |
| Duration | Shorter clips buffer faster; the upload UI limits gallery picks to **5 minutes** |

## Example (FFmpeg)

```bash
ffmpeg -i input.mov -c:v libx264 -profile:v high -crf 23 -preset medium \
  -c:a aac -b:a 128k -movflags +faststart -vf "scale='min(1920,iw)':min(1080,ih):force_original_aspect_ratio=decrease" \
  output.mp4
```

## Delivery (production)

Set **`S3_PUBLIC_URL`** to a **public S3 URL or CloudFront** base so `file_url` does not go through the API proxy. Configure bucket **CORS** for your web app origin (`GET`, `HEAD`, expose `Accept-Ranges` / `Content-Range` as needed).

See comments in [`.env.production`](.env.production) and [`src/services/media_service.rs`](src/services/media_service.rs).
