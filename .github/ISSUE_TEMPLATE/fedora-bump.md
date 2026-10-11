---
name: Fedora bump
about: Move the image to the next Fedora release
title: "Bump to Fedora "
---

Replace `44` and `45` with the old and new release.

## Change

- [ ] `image-version` in `recipes/recipe.yml`.
- [ ] The release in `static_fedora` in `tests/test.sh`. It fails until it matches `image-version`.
- [ ] Bump notes in `recipes/recipe.yml`, find them with `rg -n bump recipes/`.
- [ ] `44` in `README.md`, and in `docs/vm-acceptance.md` outside section 13.

## Check

- [ ] `just build` and `just test localhost/fruppios:latest` pass.
- [ ] CI published the `45` tag.
- [ ] [Fresh pass](https://github.com/trin94/fruppiOS/blob/main/docs/vm-acceptance.md), sections 1 to 11, on the `45` tag. Record it here.
- [ ] [Upgrade pass](https://github.com/trin94/fruppiOS/blob/main/docs/vm-acceptance.md#13-upgrade-pass), section 13, from `44` to `45`. Record it here.
