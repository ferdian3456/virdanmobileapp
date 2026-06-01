# Spec: UI/UX Fixes Batch — Flutter + BE

> Status: Draft untuk review
> Tanggal: 2026-06-01
> Jira: 1 task (key dibuat setelah spec di-ACC, issue type `Task`)
> Branch: baru, off `origin/main` (BUKAN `VIR-69` — itu FCM, sudah selesai)

---

## 1. Konteks & Aturan

- Hasil review user: 7 issue UI/UX. Digabung jadi **1 Jira task** (keputusan user).
- **Jangan campur ke VIR-69 (FCM)** — sudah committed. Branch + Jira baru.
- Stack FE: Flutter + Riverpod 3 + go_router + dio. Stack BE: Go + Fiber + pgx raw SQL.
- Ikuti konvensi existing: `VAppBar`, `AppColors`, Inter font, lucide icons, pola usecase/repository/controller berlapis di BE.
- Verifikasi tiap fix lewat `flutter analyze` (+ jalan di HP untuk yang visual).
- Repo BE: profil per-server (multi-identity Opsi B) — profil = snapshot per `server_member_profiles(server_id, user_id)`.

---

## 2. Ringkasan Issue

| # | Issue | Sisi | Ukuran |
|---|---|---|---|
| 1 | Standardisasi header semua secondary page ke gaya `<` + judul tengah (1 widget) | FE | Sedang |
| 2 | Hapus `· N` di header Comment | FE | Kecil |
| 3 | Satukan tampilan post card (feed vs detail) lewat 1 widget reusable | FE | Sedang |
| 4 | Explore tap post → feed scrollable IG-style (scroll 2 arah), hapus header "Post" | FE | Sedang |
| 5 | Hapus `chevronDown` dekoratif di header Profile | FE | Kecil |
| 6 | Lihat profil user lain (view-only) + 2 endpoint BE baru | BE + FE | Sedang |
| 6b | Fix grid profil sendiri (sekarang salah tampilkan seluruh feed) | FE | Kecil |
| 7 | Ganti history picker di Your Profile jadi bottom sheet | FE | Kecil |

---

## 3. Desain per Issue

### 3.1 Header standardization (#1)

**Keputusan user (revisi dari handoff awal):** gaya header yang BENAR = `chevronLeft` di kiri + judul **di tengah** (gaya `edit_profile` / `create_server` / `your_profile`). Semua page lain yang masih rata-kiri diseragamkan ke gaya ini lewat **satu widget**.

**Pendekatan:** upgrade `VAppBar` (`lib/core/widgets/v_app_bar.dart`) jadi gaya target, lalu migrasi semua page ke `VAppBar` + hapus widget header duplikat.

Perubahan `VAppBar`:
- Leading back: `LucideIcons.chevronLeft` (sekarang `arrowLeft`).
- Title: default **center** (`centerTitle = true`), style Inter 17px `w600` `AppColors.textPrimary` (samakan dengan `_Header` edit-profile/create-server).
- Divider bawah: standardisasi 1 warna (`AppColors.divider`).
- `actions` tetap didukung; saat tanpa actions, beri spacer 40px di kanan supaya judul benar-benar center (balance dengan leading).

Migrasi (hapus `_Header`/header custom, ganti ke `VAppBar`):
- `edit_profile_page.dart` → `VAppBar(title: 'Edit Profile')`, pertahankan fallback back ke `/settings` via `onLeadingTap`.
- `your_profile_page.dart` → `VAppBar(title: 'Your Profile')`, `onLeadingTap` = `context.pop()`.
- `create_server_page.dart` → `VAppBar(title: 'Create Server')`, `onLeadingTap` = back existing.

Page VAppBar existing (otomatis ikut gaya baru, judul jadi center): `change_email`, `change_password`, `notification_settings`, `privacy_security`, `help_center`, `static_pages` (terms/privacy), `edit_server_settings`, `join_by_invite`, `comments` (#2), `post_detail` (#4), `user_profile` (#6).

**Catatan:** `profile_page` dan `home_page` punya header khusus (tab utama: tanpa back, ada menu/switcher) — TIDAK dimigrasi ke `VAppBar`. `profile_page` tetap kena #5 (hapus chevron) saja.

### 3.2 Comment count (#2)

`comments_page.dart:115`: `title: _comments.isEmpty ? 'Comments' : 'Comments · ${_comments.length}'` → `title: 'Comments'`.

### 3.3 Shared post card (#3)

Saat ini 2 widget berbeda:
- `_FeedCard` (`home_page.dart:409`) — count inline + bookmark = gaya canonical yang diinginkan.
- `PostCard` (`widgets/post_card.dart`) — count ditumpuk di bawah, tanpa bookmark — dipakai `post_detail_page`.

**Pendekatan:** jadikan gaya `_FeedCard` sebagai isi widget shared `PostCard` (`lib/features/post/presentation/widgets/post_card.dart`). Pakai di: feed home, post-detail, dan explore-feed (#4). Hapus implementasi `PostCard` lama + `_FeedCard` private di home (home pakai `PostCard` shared).

API widget `PostCard`: `{ Post post, VoidCallback onLikeTap, VoidCallback onCommentTap, VoidCallback? onAuthorTap }` (onAuthorTap untuk #6). Tombol share & bookmark = no-op placeholder (sesuai existing).

### 3.4 Explore → IG-style scrollable feed (#4)

**Keputusan user:** Opsi B (true IG — bisa scroll ke atas & bawah). **Search di-skip** (belum ada API search; search box client-side existing dibiarkan, feed selalu pakai list penuh).

**Mekanisme (TANPA perubahan BE):**
- Explore (`explore_page.dart`) sudah memuat `_posts` (list, urut terbaru→lama, sumber `GET /servers/:serverId/posts?cursor=`) + `_nextCursor` + `_hasMore`.
- Tap post index `i` → buka halaman feed baru, oper `(posts: _posts, startIndex: i, nextCursor: _nextCursor, hasMore: _hasMore, serverId)` via go_router `extra`.
- Feed page render `_posts` penuh sebagai list `PostCard` (widget shared #3), auto-scroll ke `startIndex`.
  - Scroll ke atas = post lebih baru (sudah di memori, tidak ada fetch; berhenti natural di post terbaru = index 0).
  - Scroll ke bawah lewat batas loaded → pagination lanjut pakai `nextCursor` (sama persis pola `serverFeedProvider._load`).
- Like: optimistic + rollback per item (port pola `serverFeedProvider.toggleLike` ke state lokal halaman).
- AppBar: `VAppBar(title: 'Explore')` (menggantikan header "Post"; back ke explore).

**Loncat ke index (variable height):** pakai package `scrollable_positioned_list` (disetujui user) — `ItemScrollController.jumpTo(index: startIndex)` + lazy build (hemat memori). Tambah dependency di `pubspec.yaml` (verifikasi versi terbaru kompatibel via pub.dev saat impl).

**Halaman & route baru:**
- Widget: `lib/features/post/presentation/explore_feed_page.dart` (`ExploreFeedPage`).
- Route: `Routes.exploreFeed` + `GoRoute` membaca `state.extra`. Jika `extra == null` (deep-link/cold start) → fallback ke `PostDetailPage` single (butuh postId di path) atau tampilkan single via `getById`. Detail fallback: route `exploreFeed` butuh `postId` di path (`/explore/feed/:postId`) supaya deep-link tetap bisa load minimal 1 post; `extra` (list) opsional sebagai optimasi.
- Explore grid tap: `context.push(Routes.exploreFeed(p.id), extra: {...})` (ganti dari `push('/posts/${p.id}')`).

`PostDetailPage` (single) **tetap ada** — dipakai tap post dari grid profil (`/posts/:id`). Ikut pakai `PostCard` shared (#3) + `VAppBar` (#1).

### 3.5 Hapus chevron Profile (#5)

`profile_page.dart:221`: hapus `const Icon(LucideIcons.chevronDown, size: 18)` (dekorasi non-fungsional, tidak ada `onTap`). Header `profile_page` tetap (tab utama, ada menu settings).

### 3.6 Profil user lain view-only (#6) — BE + FE

**Scope (keputusan user): Opsi B** = clone halaman `profile_page` (info identitas + grid post user itu), **view-only** (tanpa tombol Edit Profile, tanpa settings). Tombol pengganti Edit Profile = **dihilangkan** (belum ada follow/DM).

**BE — 2 endpoint baru (reuse repo, no query baru, no migration). Detail di §4.**
1. `GET /servers/:serverId/members/:userId/profile` → info profil user.
2. `GET /servers/:serverId/members/:userId/posts?cursor=` → post user di server itu (grid).

**FE:**
- `PostApi` tambah `postsForUser({serverId, userId, cursor})` → endpoint #2.
- `ProfileApi` tambah `forUser(serverId, userId)` → endpoint #1.
- `UserProfilePage` (`user_profile_page.dart`) di-rewrite: clone struktur `profile_page` (identity block + tab grid + grid post), TANPA tombol Edit Profile & menu settings. Fetch profil (endpoint #1) + post (endpoint #2). `VAppBar(title: <nickname/username>)`.
- Route diubah dari `/profile/:userId` → `/servers/:serverId/members/:userId/profile` (mirror BE, butuh serverId). `Routes.userProfile(serverId, userId)`.
- Wiring tap author (set `onAuthorTap` / GestureDetector pada avatar+nama):
  - `PostCard` (feed + post-detail + explore-feed): serverId = `post.serverId`, userId = `post.authorId`.
  - `comments_page` (`_CommentNode`): serverId = `activeServerId` (komentar tidak simpan serverId; di app sekarang komentar selalu dalam server aktif — disetujui user), userId = `comment.authorId`.

### 3.7 Fix grid profil sendiri (#6b)

Bug pre-existing: `profile_page.dart:58-64` grid pakai `listForServer` (seluruh feed server) → salah, harus post sendiri.

**Fix:** `PostApi` tambah `postsForMe({serverId, cursor})` → `GET /servers/:serverId/posts/me` (endpoint BE **sudah ada**, `GetServerPostForMe`, belum dipakai FE). `profile_page._load` ganti panggil `postsForMe`. No BE change.

### 3.8 History picker bottom sheet (#7)

`your_profile_page.dart` `_HistoryPicker` (line 574) pakai `DropdownButtonFormField` → menu overlay menutupi form.

**Fix:** ganti dengan pola `create_server_page` category picker:
- Field tappable (`_CategoryPickerField` style, line 509) menampilkan pilihan terpilih / placeholder "Choose profile…" + `chevronDown`.
- `onTap` → `showModalBottomSheet` (drag handle + rounded top, pola `_openCategoryPicker` line 96) berisi list `ProfileHistoryItem` (`nickname · serverName`).
- Tap baris → `_copyFromHistory(item)` + `Navigator.pop`.

---

## 4. Perubahan BE (detail) — hanya #6

Layered: controller → usecase → repository (existing pattern). Reuse repo method, no SQL baru, no migration.

### Endpoint 1 — `GET /servers/:serverId/members/:userId/profile`
- Auth: protected. Guard: requester WAJIB member server (`ServerRepository.CheckServerMember`, count==0 → `ForbiddenError`) — cegah enumerasi roster server private.
- `profile_controller.go`: handler `GetServerProfileByUserId` — `requesterId = ctx.Locals("userId")`, `serverId, userId = ctx.Params(...)`.
- `profile_usecase.go`: method baru — validasi UUID `serverId` + `userId`, `CheckServerMember(serverId, requesterId)`, lalu `ProfileRepository.GetServerMemberProfile(serverId, userId, minioFullUrl)` (reuse, line 361).
- Response: `model.ServerMemberProfileResponse` (existing). 404 kalau target tidak punya profil.
- **NotFound wording:** ubah pesan di repo (`profile_repository.go:400`) jadi netral `"Profile not found in this server"` (sekarang `"You don't have a profile in this server"`) — dipakai dua endpoint (`/me` & member), dua-duanya tetap akurat.

### Endpoint 2 — `GET /servers/:serverId/members/:userId/posts?cursor=`
- Auth + guard sama (member-guard requester).
- `post_controller.go`: handler `GetServerPostsByUserId`.
- `post_usecase.go`: method baru — validasi UUID, member-guard requester, reuse `PostRepository.GetServerPostForMe(limit, serverId, userId, cursor, minioFullUrl)` (line 404; query sudah filter `author_id = userId`, cursor-paginated). **Set `IsOwner = false`** pada hasil (repo hardcode `true` di line 483 — tidak akurat untuk user lain; grid FE abaikan field ini, set false untuk kebersihan).
- Response: `model.ServerPostListResponse` (existing, cursor pagination).

### Route (`route/route.go`, profileGroup line 128-131 / serverGroup)
- Tambah di group ber-auth:
  - `GET /servers/:serverId/members/:userId/profile`
  - `GET /servers/:serverId/members/:userId/posts`
- Tidak konflik dengan route `/servers/...` existing (segmen `members/:userId/...` unik).

### Dokumentasi & test BE (per workflow backend)
- Swagger annotation di kedua handler.
- Flow docs: `docs/flows/id/` + `docs/flows/en/` (nama file = tag `@Description.markdown`), set file identik 2 locale.
- Integration test: `tests/integration/` — happy path + edge (requester bukan member → 403, target tanpa profil → 404, UUID invalid → 400, unauthorized → 401).

---

## 5. Daftar File Berubah

**FE (`virdanmobileapp-flutter/`):**
- `lib/core/widgets/v_app_bar.dart` — upgrade gaya (#1).
- `lib/features/profile/presentation/edit_profile_page.dart` — `VAppBar` (#1).
- `lib/features/profile/presentation/your_profile_page.dart` — `VAppBar` (#1) + history picker bottom sheet (#7).
- `lib/features/server/presentation/create_server_page.dart` — `VAppBar` (#1).
- `lib/features/post/presentation/comments_page.dart` — judul "Comments" (#2) + tap author (#6).
- `lib/features/post/presentation/widgets/post_card.dart` — jadi shared canonical card (#3) + `onAuthorTap`.
- `lib/features/post/presentation/home_page.dart` — pakai `PostCard` shared, hapus `_FeedCard` (#3).
- `lib/features/post/presentation/post_detail_page.dart` — `PostCard` shared + `VAppBar` (#1, #3).
- `lib/features/post/presentation/explore_feed_page.dart` — **baru** (#4).
- `lib/features/explore/presentation/explore_page.dart` — tap → push exploreFeed (#4).
- `lib/features/profile/presentation/profile_page.dart` — hapus chevron (#5) + grid pakai postsForMe (#6b).
- `lib/features/profile/presentation/user_profile_page.dart` — rewrite view-only (#6).
- `lib/features/post/data/post_api.dart` — `postsForMe`, `postsForUser`.
- `lib/features/profile/data/profile_api.dart` — `forUser`.
- `lib/core/router/routes.dart` + `app_router.dart` — route `exploreFeed`, ubah `userProfile` (serverId+userId).
- `pubspec.yaml` — `scrollable_positioned_list`.

**BE (`virdanproject/`):**
- `internal/delivery/http/profile_controller.go` — `GetServerProfileByUserId`.
- `internal/delivery/http/post_controller.go` — `GetServerPostsByUserId`.
- `internal/usecase/profile_usecase.go` — method profil-by-userId + guard.
- `internal/usecase/post_usecase.go` — method posts-by-userId + guard + `IsOwner=false`.
- `internal/repository/profile_repository.go` — pesan NotFound netral (line 400).
- `internal/delivery/http/route/route.go` — 2 route baru.
- `docs/flows/{id,en}/*` + swagger + `tests/integration/*`.

---

## 6. Testing

- FE: `flutter analyze` bersih tiap perubahan; uji manual di HP (header semua page center, explore-feed scroll 2 arah + anchor benar, profil user lain view-only, picker bottom sheet, grid profil sendiri = post sendiri).
- BE: integration test 2 endpoint baru (happy + 403/404/400/401). `make test` butuh ~10 menit — minta izin user dulu.

---

## 7. Out of Scope / Tech Debt

- Follow / Direct Message (tombol di profil user lain dihilangkan dulu).
- Search API di explore (di-skip; search client-side existing dibiarkan).
- Bookmark & share post (tetap no-op placeholder seperti existing).
- Scroll-up "load newer" di explore-feed tidak perlu (grid selalu mulai dari post terbaru).

---

## 8. Proses (Jira, branch, commit, PR)

1. Search Jira VIR → konfirmasi title/desc/issue type (`Task`) ke user → create.
2. Branch baru = `VIR-XXX`, off `origin/main`, di FE repo + BE repo (kerja #6 di dua repo).
3. Commit format `VIR-XXX: <title>`. BE dulu (#6 endpoint) lalu FE, atau FE-only issues paralel.
4. PR per repo → main, link Jira.
5. Update CLAUDE.md project jika ada pattern/standard baru (mis. `VAppBar` jadi satu-satunya header standard).
