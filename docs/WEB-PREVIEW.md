# Project 2 web preview

This branch builds the Flutter web app and publishes it with GitHub Pages.

- Workflow: `.github/workflows/project2-web-preview.yml`
- Branch: `feature/sticker-gif-system`
- Expected Pages path: `/arad-portfolio-/`
- The live URL is only considered ready after the GitHub Pages deploy job succeeds.

## Build checks

The workflow runs dependency resolution, Dart analysis, Flutter tests, and a release web build before uploading the Pages artifact. Pull request runs validate the build but do not deploy. Push runs on this feature branch perform the deployment.

## GIF search configuration

Add repository Actions secrets named `TENOR_API_KEY` and/or `GIPHY_API_KEY` to enable provider search. The app can still build without them, but remote GIF search may be unavailable.
