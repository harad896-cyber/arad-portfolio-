# Animated stickers and GIFs

## Storage and catalog
- Upload Lottie JSON files to the public Supabase Storage bucket `stickers`.
- Create one `sticker_packs` row per pack.
- Create `stickers` rows with `pack_id`, `asset_path`, `format='lottie'`, and optional `preview_path`.
- Asset paths are relative to the bucket root. The app resolves them with `getPublicUrl`.
- Catalog tables are read-only for `anon` and `authenticated`; manage packs from the Supabase dashboard or a trusted admin process.

## GIF provider keys
Set repository Actions secrets named `TENOR_API_KEY` and/or `GIPHY_API_KEY`.
The web preview injects them at build time as public provider keys. Restrict keys by provider/domain and usage limits.

## Preview
The workflow builds Flutter Web, runs analyzer/tests, and deploys to GitHub Pages.
Enable **Settings → Pages → Build and deployment → GitHub Actions** for this repository.
