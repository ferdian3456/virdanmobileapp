# Virdan Mobile UI Guideline (Flutter)

> **Scope**: Aturan komponen + interaksi untuk seluruh Flutter app Virdan.
> **Audience**: Engineer (saat ini hanya solo founder).
> **Relasi**: `MIGRATION_QUASAR_TO_FLUTTER.md` (parent migration plan). `virdan/virdan-reference-ui/` (visual reference).
> **Style guide**: Light only, primary `#007BFF`, Inter font, Instagram-inspired hybrid Discord.
> **Last updated**: 2026-05-24

---

## 0. Cara Pakai Doc Ini

1. Sebelum implement page/komponen baru, **baca section yang relevan** (loading, toast, button, dll).
2. Kalau case tidak cover di sini, **tambah entry** di section yang sesuai — jangan improvise.
3. Kalau ada konflik antar section, **section yang lebih spesifik menang** (e.g., "Form" lebih spesifik dari "Input").
4. Anti-patterns di §17 = jangan dilanggar.

---

## 1. Design Tokens

### 1.1 Color

```dart
// lib/core/theme/tokens.dart
abstract final class AppColors {
  // Primary
  static const primary = Color(0xFF007BFF);          // brand blue
  static const primarySoft = Color(0xFFE7F1FF);      // background tint
  static const primaryDark = Color(0xFF0056CC);      // pressed / active

  // Surfaces
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8F9FA);
  static const border = Color(0xFFDEE2E6);
  static const divider = Color(0xFFE9ECEF);

  // Text
  static const textPrimary = Color(0xFF212529);
  static const textSecondary = Color(0xFF6C757D);
  static const textTertiary = Color(0xFFADB5BD);
  static const textOnPrimary = Color(0xFFFFFFFF);

  // Semantic
  static const success = Color(0xFF28A745);
  static const error = Color(0xFFDC3545);
  static const warning = Color(0xFFFFC107);
  static const info = Color(0xFF17A2B8);

  // Overlay
  static const overlay = Color(0x80000000);          // modal backdrop
  static const skeletonBase = Color(0xFFE9ECEF);
  static const skeletonHighlight = Color(0xFFF8F9FA);
}
```

### 1.2 Typography

Font keluarga: **Inter** (bundle TTF di `assets/fonts/`, register di `pubspec.yaml`). Setelah register, akses lewat `TextStyle(fontFamily: 'Inter')` atau via `AppTextStyles` di bawah.

```dart
abstract final class AppTextStyles {
  static const _base = TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, height: 1.4);

  // Display (jarang dipakai, hanya untuk landing/empty state)
  static final display = _base.copyWith(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2);

  // Headings
  static final h1 = _base.copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25);
  static final h2 = _base.copyWith(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3);
  static final h3 = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3);

  // Body
  static final body = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400);
  static final bodyMedium = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w500);
  static final bodyStrong = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);

  // Small
  static final caption = _base.copyWith(fontSize: 14, color: AppColors.textSecondary);
  static final captionStrong = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500);
  static final micro = _base.copyWith(fontSize: 12, color: AppColors.textTertiary);

  // Button label
  static final button = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
}
```

### 1.3 Spacing Scale

Skala kelipatan 4 — predictable, mudah dihafal.

```dart
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;     // default padding screen
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;
}
```

### 1.4 Radius

```dart
abstract final class AppRadius {
  static const sm = 8.0;       // chip, badge
  static const md = 12.0;      // input, card kecil
  static const lg = 14.0;      // button
  static const xl = 16.0;      // card besar, modal
  static const xxl = 24.0;     // bottom sheet top edge
  static const pill = 999.0;   // pill / avatar
}
```

### 1.5 Elevation / Shadow

```dart
abstract final class AppElevation {
  static const none = <BoxShadow>[];

  static const card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const sheet = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, -2)),
  ];

  static const overlay = [
    BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
}
```

### 1.6 Motion (Duration + Curve)

```dart
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);       // tap feedback, micro
  static const medium = Duration(milliseconds: 250);     // page transition, sheet
  static const slow = Duration(milliseconds: 400);       // illustrative anim
  static const toast = Duration(milliseconds: 2600);     // standar
  static const toastError = Duration(milliseconds: 5000);
  static const toastWarning = Duration(milliseconds: 3500);

  static const standardCurve = Curves.easeInOutCubic;
  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;
}
```

---

## 2. Loading Patterns — Decision Matrix

> **Aturan utama**: User HARUS tahu sistem sedang kerja dalam < 100ms. Pilih indicator yang sesuai konteks.

### 2.1 Quick Reference

| Pattern | Kapan pakai | JANGAN pakai untuk | Component |
|---|---|---|---|
| **Skeleton** | Initial load list/feed/detail dengan layout known | Load < 200ms, button submit, mutation | `VSkeleton` (shimmer) |
| **Spinner in-place (button)** | Submit/save/delete mutation triggered by button | List/feed load | `VButton(loading: true)` |
| **Spinner centered (small)** | Section refresh, nested area | Top-level page load | `CircularProgressIndicator` size 24 |
| **Progress ring/bar** | File upload, multi-step progress measurable | Indeterminate ops | `VProgressRing` |
| **Pull-to-refresh** | Top of feed/list yang refresh-able | Detail page, form | `RefreshIndicator` |
| **Optimistic update** | Like, follow, comment send | Destructive (delete) | Manual state update + rollback |
| **Linear progress bar** | Top of screen, indicate background fetch | Mutation in-button | `LinearProgressIndicator` |

### 2.2 Skeleton — Decision Rules

**PAKAI skeleton ketika:**
- Initial load list/grid dimana **layout sudah diketahui** sebelum data datang.
  - Contoh: Home feed (5 post card skeleton), Explore (10 server card skeleton), Notifications (5 notif row skeleton).
- Initial load detail page dimana komponen ter-fixed.
  - Contoh: ProfilePage (avatar + name + stats skeleton + posts grid skeleton).
- Image placeholder sebelum cached image done load (gabung dengan `cached_network_image.placeholder`).

**JANGAN pakai skeleton ketika:**
- Load yang biasanya < 200ms (memory/cache hit) — jadi flash, mengganggu.
- Button submit / mutation — pakai spinner in-button.
- Layout result-nya tidak deterministic (mis. error state, empty state mungkin lebih besar dari skeleton). Pakai spinner centered.
- Refresh dari pull-to-refresh — `RefreshIndicator` sudah cukup, jangan layer skeleton di atasnya.

**Behavior**:
- Minimum show duration: 300ms (kalau load lebih cepat, tetap show 300ms — hindari flicker).
- Maximum show duration: 8s (kalau lebih, switch ke error state dengan retry).
- Shimmer animation: 1.5s loop, dari kiri ke kanan.

**Contoh implementasi**:

```dart
ref.watch(feedProvider).when(
  loading: () => const FeedSkeleton(count: 5),
  error: (e, _) {
    // Surface error via toast. Empty state with retry CTA covers the visible
    // page so user has an obvious action.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showApiErrorToast(ref, e, onRetry: () => ref.invalidate(feedProvider));
    });
    return VEmptyState(
      icon: LucideIcons.wifiOff,
      title: 'Gagal memuat',
      subtitle: 'Periksa koneksi internet kamu.',
      cta: VButton(label: 'Coba lagi', onPressed: () => ref.invalidate(feedProvider)),
    );
  },
  data: (posts) => posts.isEmpty
      ? const VEmptyState(icon: LucideIcons.fileText, title: 'Belum ada post')
      : ListView.builder(itemBuilder: (_, i) => PostCard(post: posts[i])),
);
```

### 2.3 Spinner In-Place (Button) — Decision Rules

**PAKAI ketika:**
- Submit form (login, signup step, create post, create server, send comment).
- Save action (edit profile save, server settings save).
- Delete action (kombinasi dengan confirm dialog).
- Any mutation triggered by user tap pada button.

**JANGAN pakai ketika:**
- Loading list — pakai skeleton.
- Background refresh — pakai pull-to-refresh atau linear progress.

**Behavior**:
- Label berubah jadi `loadingLabel` (e.g., "Menyimpan...") atau hilang + spinner 18px.
- Button disabled selama loading (cegah double-submit).
- Min duration spinner: 400ms (kalau response < 400ms, tetap show 400ms — feel responsive, tidak flash).

**Contoh**:

```dart
VButton(
  label: 'Login',
  loadingLabel: 'Masuk...',
  loading: state.isSubmitting,
  onPressed: state.isSubmitting ? null : () => controller.submit(),
);
```

### 2.5 Spinner Centered Small — Decision Rules

**PAKAI ketika:**
- Section refresh inside page (mis. comments section reload setelah post comment).
- Tab content load (saat user switch tab dan content baru fetch).
- Pagination "Load more" footer.

**Behavior**:
- Size 24px.
- Padding 16px atas+bawah.
- Color: `AppColors.textTertiary` atau `AppColors.primary` kalau prominent.

### 2.6 Progress Ring / Bar — Decision Rules

**PAKAI ketika:**
- File upload dengan progress measurable (avatar upload, post image upload).
- Multi-step process dengan known total (e.g., onboarding step 2/5).
- Background fetch besar yang user perlu tahu progressnya.

**Behavior**:
- Mode `overlay`: di tengah image picker preview, dengan backdrop tipis (`Color(0x66000000)`).
- Mode `inline`: di bawah/atas content, tanpa backdrop.
- Show percentage text kalau muat (`"45%"`).
- Smooth animation, jangan jumpy.

**Contoh** (`VProgressRing`):

```dart
VProgressRing(
  progress: uploadState.percent,  // 0.0 - 1.0
  mode: VProgressRingMode.overlay,
  label: 'Mengunggah... ${(uploadState.percent * 100).toInt()}%',
);
```

### 2.7 Pull-to-Refresh — Decision Rules

**PAKAI di:**
- Top of feed (home, server detail feed).
- Notifications list.
- Server discovery list.
- Profile posts grid.

**JANGAN pakai di:**
- Detail pages (post detail, profile detail).
- Form pages.
- Settings list.

**Behavior**:
- Trigger: pull down 80px.
- Show native `RefreshIndicator` (Material) atau `CupertinoSliverRefreshControl` (iOS). Pilih `RefreshIndicator.adaptive` untuk auto-pick.
- Vibrate haptic medium pada trigger (iOS feels native).
- Refresh function: `ref.invalidate(provider)` + `await ref.read(provider.future)`.

**Contoh**:

```dart
RefreshIndicator.adaptive(
  onRefresh: () async {
    HapticFeedback.mediumImpact();
    ref.invalidate(feedProvider);
    await ref.read(feedProvider.future);
  },
  child: ListView(...),
);
```

### 2.8 Optimistic Update — Decision Rules

**PAKAI untuk:**
- Like / unlike post (toggle button visible langsung).
- Bookmark (kalau ada).
- Follow / unfollow (kalau ada).
- Send comment (insert ke list dengan status "Sending...", confirm setelah API success).

**JANGAN pakai untuk:**
- Delete (perlu konfirmasi).
- Create resource yang return ID dari server (tunggu ID).
- Mutation dengan side-effect besar (e.g., kick member).

**Behavior**:
- Update local state instant.
- Pada error: rollback ke state sebelum + toast error.
- Pada success: no-op (state sudah benar).

**Contoh** (like):

```dart
Future<void> toggleLike(String postId) async {
  final previous = state;
  state = state.copyWith(liked: !state.liked, likeCount: state.liked ? state.likeCount - 1 : state.likeCount + 1);
  try {
    if (previous.liked) {
      await _api.unlikePost(postId);
    } else {
      await _api.likePost(postId);
    }
  } catch (e) {
    state = previous;
    showApiErrorToast(e);
  }
}
```

### 2.9 Linear Progress Bar — Decision Rules

**PAKAI ketika:**
- Background fetch berjalan dengan content masih visible (e.g., refresh comments while user reading post).
- Indeterminate progress di top of screen.

**Behavior**:
- Posisi: di bawah AppBar.
- Height: 2px.
- Color: `AppColors.primary`.
- Hide saat selesai.

---

## 3. Toast — Decision Matrix

> **Aturan**: Toast = feedback non-blocking untuk async action. Bukan untuk validation, bukan untuk konfirmasi destruktif.

### 3.1 Tipe & Kapan

| Type | Kapan | Auto-dismiss | Contoh |
|---|---|---|---|
| **Success** | Async action confirmed sukses | 2.6s | "Post berhasil dibuat", "Profil disimpan" |
| **Error** | API/network error | 5s | "Gagal memuat feed", "Tidak ada koneksi" |
| **Warning** | Recoverable issue, attention needed | 3.5s | "Koneksi lambat", "Versi app baru tersedia" |
| **Info** | Tips / non-critical info | 2.6s | "Kode invite baru dibuat", "Tip: tarik ke bawah untuk refresh" |

### 3.2 Don't Use Toast For

- **Form validation error** → pakai inline `VFieldError` di bawah input.
- **Critical confirmation** (delete server, logout) → pakai `AlertDialog`.
- **Persistent state** (e.g., "Belum punya server") → pakai empty state.
- **Long content** (multi-line explanation) → pakai bottom sheet atau page.
- **Action result yang user TIDAK trigger** (push notification, background event) → pakai notif system, bukan toast.

### 3.3 Behavior

- **Position**: Top, di bawah safe area.
- **Max stack**: 3. Toast keempat replace yang tertua.
- **Dismiss**: Auto-dismiss + tap untuk dismiss manual + swipe up untuk dismiss.
- **Animation**: Slide-in dari atas + fade. Durasi 250ms enter, 200ms exit.
- **Width**: Lebar layar - 32px (16 padding kiri+kanan).
- **Z-index**: Di atas everything kecuali full-screen dialog modal.

### 3.4 Error Toast — onRetry Button

**PAKAI `onRetry`:**
- Untuk **operasi LOAD/FETCH** yang aman diulang (GET endpoint).
- Contoh: "Gagal memuat feed" + retry button.

**JANGAN pakai `onRetry`:**
- Untuk **mutation** (POST/PUT/PATCH/DELETE) — retry bisa dobel write.
- Contoh: jangan tampilkan retry pada "Gagal mengirim komentar" (mungkin sudah ter-create di BE tapi response lost).

### 3.5 API Surface

```dart
// useToast equivalent (Riverpod controller)
final toast = ref.read(toastControllerProvider.notifier);

toast.success(title: 'Post berhasil dibuat');
toast.error(title: 'Gagal memuat feed', onRetry: () => ref.invalidate(feedProvider));
toast.warning(title: 'Koneksi lambat', caption: 'Mencoba ulang...');
toast.info(title: 'Tip: tarik untuk refresh');

// Untuk error dari API, pakai helper:
try {
  await api.fetchFeed();
} catch (e) {
  showApiErrorToast(ref, e, onRetry: () => ref.invalidate(feedProvider));
}
```

### 3.6 Anti-Pattern Toast

- Tampil >3s untuk success — annoying.
- Tampil success setelah action yang clearly visible (e.g., like button sudah berubah warna — TIDAK perlu toast "Liked").
- Tampil error dengan pesan teknis ("HTTP 500" — translate ke "Server sedang sibuk, coba lagi").
- Tampil toast bertumpuk untuk same action (mis. spam tap submit, tampil 5 toast).

---

## 4. Inline Field Error (`VFieldError`)

### 4.1 Kapan Pakai

- **Form validation** (email format salah, password terlalu pendek).
- **Per-field server error** (BE response `{ error: { code: 'EMAIL_TAKEN', param: 'email' } }`).
- Visibility setelah user **blur** input atau **submit** form. Jangan show saat user masih ketik (cegah harassment).

### 4.2 Behavior

- Border input berubah merah (`AppColors.error`).
- Badge "!" appear di kanan input (ikon `LucideIcons.alertCircle`).
- Error message text muncul di bawah input (font caption 14px, `AppColors.error`).
- Shake animation horizontal 8px × 2 bounce saat error pertama tampil (durasi 300ms).
- Saat user start typing lagi → error hide, border kembali normal.

### 4.3 Source of Error

1. **Client-side validation** (validator function `TextFormField.validator`) — tampil setelah blur atau submit.
2. **Server-side per-field error** — parse `error.param`, attach error ke field tersebut.

```dart
TextFormField(
  controller: emailCtrl,
  decoration: AppInputDecoration(
    label: 'Email',
    errorText: state.fieldErrors['email'],  // dari server response
  ),
  validator: (v) {
    if (v == null || v.isEmpty) return 'Email wajib diisi';
    if (!EmailValidator.validate(v)) return 'Format email tidak valid';
    return null;
  },
);
```

---

## 5. Empty State

### 5.1 Kapan

Saat list/grid kosong **karena memang kosong** (bukan loading, bukan error).

### 5.2 Komposisi

1. **Icon** — lucide icon 48px, color `AppColors.textTertiary`.
2. **Title** — h3 bold, color `AppColors.textPrimary`. Singkat, deskriptif. Contoh: "Belum ada post".
3. **Subtitle** (optional) — body 15px, color `AppColors.textSecondary`. Action hint. Contoh: "Jadi yang pertama posting di server ini!".
4. **CTA button** (optional) — `VButton` size medium. Hanya kalau ada action obvious. Contoh: "Buat post pertama".

### 5.3 Contoh Cases

| Context | Icon | Title | Subtitle | CTA |
|---|---|---|---|---|
| Home feed empty (no server) | `users` | "Belum ada server" | "Buat atau gabung server untuk mulai" | "Cari server" |
| Home feed empty (server tapi belum ada post) | `fileText` | "Belum ada post" | "Jadi yang pertama posting!" | "Buat post" |
| Comments empty | `messageCircle` | "Belum ada komentar" | "Jadi yang pertama berkomentar" | (none — input ada di bawah) |
| Notifications empty | `bell` | "Belum ada notifikasi" | "Notifikasi akan muncul di sini" | (none) |
| Search no result | `searchX` | "Tidak ada hasil" | "Coba kata kunci lain" | (none) |
| Profile no post | `image` | "Belum ada post" | "Post Anda akan muncul di sini" | (none kalau bukan own profile) |

### 5.4 Implementation

```dart
VEmptyState(
  icon: LucideIcons.fileText,
  title: 'Belum ada post',
  subtitle: 'Jadi yang pertama posting di server ini!',
  cta: VButton(label: 'Buat post', onPressed: () => context.push('/app/create-post')),
);
```

---

## 6. Error → Toast Pattern (Project Decision)

**Keputusan project**: Virdan TIDAK memakai full-page error component. Semua error di-surface lewat **toast** (lihat §3). Page tetap render — kalau load fail dan tidak ada data, fallback ke **empty state** dengan CTA retry.

Alasan:
- Toast = non-blocking. User bisa retry tanpa kehilangan konteks.
- Full-page error = jarang dibutuhkan di mobile context Virdan (cache-friendly, retry mudah).
- Mengurangi component sprawl + state machine logic.

### 6.1 Decision Tree

| Skenario | Tampilan |
|---|---|
| Initial load fail, **ada cached data** | Tampilkan cached data + toast error (`onRetry` aman) |
| Initial load fail, **tanpa cached data** | `VEmptyState` ber-CTA "Coba lagi" + toast error (`onRetry`) |
| Background refresh fail | Toast error (jangan flush page) |
| Mutation fail (POST/PUT/DELETE) | Toast error **tanpa `onRetry`** (cegah dobel write) |
| Critical state (session corrupted, auth expired) | Redirect ke `/auth/login` + toast info "Sesi habis, silakan login lagi" |

### 6.2 Implementasi

Pakai helper `showApiErrorToast(ref, error, {onRetry})` dari `core/errors/`. Mapping error → toast title:

- `NetworkError` → "Tidak ada koneksi internet"
- `TimeoutError` → "Permintaan terlalu lama"
- `ApiError` → pakai `error.message` (dari BE envelope)
- `UnknownError` → "Terjadi kesalahan. Coba lagi nanti"

`onRetry` HANYA untuk GET/load operations. Mutation = no retry.

---

## 7. Dialog vs Bottom Sheet vs Full Page Modal

### 7.1 Decision Tree

```
User decision required?
├── Ya, simple yes/no atau destruktif?
│   └── AlertDialog (Material) atau CupertinoAlertDialog (adaptive)
├── Ya, pilih dari list pendek (<7 option)?
│   └── BottomSheet (pakai showModalBottomSheet)
├── Ya, pilih dari list panjang atau form pendek?
│   └── DraggableScrollableSheet (initial 50%, max 90%)
└── Ya, multi-step atau form lengkap?
    └── Full page (pakai context.push / showGeneralDialog)
```

### 7.2 Dialog — Kapan & Spec

**Kapan**:
- Konfirmasi destruktif: delete post, delete server, logout, leave server.
- Konfirmasi kritis: discard unsaved changes.
- Simple choice 2-3 option dimana label cukup explain context.

**Spec**:
- Width: min 280px, max layar - 48px.
- Padding: 24px.
- Title: h3 bold.
- Body: body 16px.
- Buttons: 2 max (destructive right-aligned, cancel left).
  - Destructive: `VButton(variant: destructive)` (background `AppColors.error`).
  - Cancel: `VButton(variant: ghost)`.
- Backdrop: `AppColors.overlay` tap-to-dismiss = ON kecuali destructive critical (mis. delete server).

**Contoh**:

```dart
final confirmed = await showAdaptiveDialog<bool>(
  context: context,
  builder: (_) => AlertDialog.adaptive(
    title: const Text('Hapus server?'),
    content: const Text('Semua post, komentar, dan member akan hilang permanen. Aksi ini tidak bisa dibatalkan.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        style: TextButton.styleFrom(foregroundColor: AppColors.error),
        child: const Text('Hapus'),
      ),
    ],
  ),
);
if (confirmed == true) await controller.deleteServer();
```

### 7.3 Bottom Sheet — Kapan & Spec

**Kapan**:
- Pick option dari list pendek (e.g., post action menu: Edit / Delete / Report).
- Picker selection (e.g., aspect ratio picker di CreatePost step 2).
- Sort / filter selection.

**Spec**:
- Top edge: radius `AppRadius.xxl` (24).
- Drag handle: 36×4 px, color `AppColors.textTertiary`, top center, padding 8.
- Backdrop: `AppColors.overlay`.
- Tap backdrop / drag down = dismiss.
- Padding content: `AppSpacing.lg` (16) horizontal, `AppSpacing.md` (12) vertical.

```dart
showModalBottomSheet(
  context: context,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
  ),
  builder: (_) => PostActionSheet(post: post),
);
```

### 7.4 Draggable Sheet (Scrollable) — Kapan & Spec

**Kapan**:
- List panjang yang user mungkin scroll (e.g., emoji picker, server invite list).
- Form pendek (e.g., create comment dengan @mention).

**Spec**:
- Initial size: 0.5 (half screen).
- Min size: 0.25.
- Max size: 0.9 (jangan full screen — pakai full page kalau begitu).

### 7.5 Full Page Modal — Kapan & Spec

**Kapan**:
- Multi-step flow (e.g., CreatePost 3-step).
- Form lengkap (e.g., EditProfile, CreateServer).
- Detail view yang butuh navigation kembali (post detail, profile detail).

**Spec**:
- Pakai `context.push('/route')` (go_router) — bukan `showDialog`.
- App bar: `VAppBar` dengan back arrow (`LucideIcons.x` untuk close-style atau `arrowLeft` untuk back-style).
- Page transition: platform-native (slide right iOS, fade Android).

---

## 8. Button States (`VButton`)

### 8.1 Variants

| Variant | Background | Foreground | Border | Kapan |
|---|---|---|---|---|
| **primary** | `AppColors.primary` | `textOnPrimary` (white) | none | Main action (Submit, Save, Continue, Buat) |
| **secondary** | `AppColors.surface` | `AppColors.primary` | `AppColors.border` 1px | Secondary action (Cancel, Back, Skip) |
| **ghost** | transparent | `AppColors.primary` | none | Tertiary action (text-only style) |
| **destructive** | `AppColors.error` | white | none | Delete, Logout, Remove |
| **outline** | transparent | `AppColors.primary` | `AppColors.primary` 1.5px | Less prominent CTA (Join, Follow) |

### 8.2 Sizes

| Size | Height | Horizontal Padding | Font Size | Kapan |
|---|---|---|---|---|
| sm | 36 | 12 | 14 | Inline action (like, follow) |
| md (default) | 44 | 16 | 15 | Section CTA |
| lg | 48 | 20 | 16 | Primary page CTA (Submit form) |

### 8.3 States

- **default**: normal display.
- **pressed**: opacity 0.85 + scale 0.98 selama 100ms (haptic light feedback).
- **disabled**: opacity 0.4, no interaction, no hover.
- **loading**: label hide, spinner 18px white in-place, button disabled.
- **focus** (keyboard): outline 2px `AppColors.primary` outset.

### 8.4 Anti-Patterns

- Stack 3+ primary button di satu page — pilih satu primary.
- Disable button tanpa visual hint kenapa (kasih tooltip atau inline hint).
- Loading button bisa di-tap berkali-kali (double submit) — selalu disable saat loading.
- Loading state tanpa min duration → flash, jelek. Min 400ms.

---

## 9. Input States (`VInput`)

### 9.1 States

| State | Border | Background | Helper |
|---|---|---|---|
| idle | `AppColors.border` 1px | white | hint text grey |
| focus | `AppColors.primary` 1.5px | white | hint hilang |
| error | `AppColors.error` 1.5px | white | error message + icon `alertCircle` |
| disabled | `AppColors.border` 1px dashed | `AppColors.surface` | helper grey |
| success (opsional) | `AppColors.success` 1px | white | icon `check` di trailing |

### 9.2 Spec

- Height: 52px (default).
- Padding horizontal: 16px.
- Radius: `AppRadius.md` (12).
- Label position: floating (Material style) atau outside-above (custom).
- Helper text: di bawah input, 14px, `AppColors.textSecondary`. Untuk error → `AppColors.error`.

### 9.3 Validation Timing

| Trigger | When validate |
|---|---|
| **onBlur** | Setelah user pindah focus dari input — show error kalau ada. |
| **onChange** | TIDAK tampil error saat masih ketik. Hide error existing kalau user start typing lagi. |
| **onSubmit** | Validate semua field. Show error untuk yang invalid. Focus auto-jump ke first invalid. |

Pengecualian: **password match** validation di signup → re-validate setiap perubahan kedua field, supaya feedback instant.

### 9.4 Anti-Patterns

- Error muncul saat user pertama kali click input (premature).
- Helper text panjang lebih dari 1 line — pindah ke tooltip atau separate explanation.
- Password input tanpa show/hide toggle — wajib ada (`LucideIcons.eye` / `eyeOff`).

---

## 10. Navigation

### 10.1 Push vs Replace vs Modal

| Action | Method | Kapan |
|---|---|---|
| Push (stack) | `context.push('/route')` | Drill deeper (post detail dari feed, profile detail) |
| Replace | `context.go('/route')` | Linear flow tanpa back-need (login → home, logout → login) |
| Modal full page | `context.pushNamed('createPost')` dengan custom transition slide-up | Composer-like action (create post, create server) |
| Pop | `context.pop()` | Back to previous |
| Pop until | `context.go('/app/home')` (replace dengan home) | Reset after deep flow (e.g., post created → balik ke home) |

### 10.2 Back Button Behavior

- iOS: swipe-from-left = back. Auto-handled go_router + `CupertinoPageRoute`.
- Android: hardware back = back. Auto-handled.
- Custom AppBar: `LucideIcons.arrowLeft` untuk back, `LucideIcons.x` untuk close-modal.
- **Tap behavior**: HapticFeedback.lightImpact() saat tap back (native feel).

### 10.3 Unsaved Changes Warning

Saat form dirty + user trigger back:

```dart
PopScope(
  canPop: !state.isDirty,
  onPopInvokedWithResult: (didPop, _) async {
    if (didPop || !state.isDirty) return;
    final confirm = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => AlertDialog.adaptive(
        title: const Text('Buang perubahan?'),
        content: const Text('Perubahan yang belum disimpan akan hilang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) context.pop();
  },
  child: ...,
);
```

### 10.4 Deep Link

- Format: `virdan://app/server/{id}` atau `https://virdan.app/server/{id}`.
- Handle di go_router config. Jangan implement custom routing parsing.

### 10.5 Bottom Tab Navigation

Pakai `StatefulShellRoute.indexedStack` (go_router 14+) — preserve scroll position per tab.

Tabs (Virdan):
1. Home (`LucideIcons.house`)
2. Explore (`LucideIcons.search`)
3. Create (`LucideIcons.plus`) — note: tap → bottom sheet pick (Post / Server), bukan navigate
4. Notifications (`LucideIcons.bell`)
5. Profile (`LucideIcons.user`) atau avatar user

---

## 11. List & Feed

### 11.1 Pagination

**Cursor-based** (BE pakai `nextCursor`):

```dart
class FeedNotifier extends AutoDisposeAsyncNotifier<FeedState> {
  Future<void> loadMore() async {
    final current = state.requireValue;
    if (current.nextCursor == null || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _api.fetchFeed(cursor: current.nextCursor);
      state = AsyncData(FeedState(
        posts: [...current.posts, ...next.posts],
        nextCursor: next.nextCursor,
        loadingMore: false,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(loadingMore: false));
      showApiErrorToast(ref, e);  // no retry untuk pagination — user swipe lagi
    }
  }
}
```

### 11.2 Infinite Scroll Trigger

- Trigger load more saat user scroll ke **80% bottom** (bukan 100% — kasih buffer untuk smooth UX).
- Pakai `ScrollController.addListener` atau `NotificationListener<ScrollNotification>`.

### 11.3 List States

| State | Display |
|---|---|
| Initial loading | Skeleton (§2.2) |
| Initial error | `VEmptyState` ber-CTA "Coba lagi" + toast error (§6) |
| Empty | `VEmptyState` (§5) |
| Has data, loading more | List + footer spinner small (§2.5) |
| Has data, load more error | List + footer "Gagal load. Tap untuk coba lagi" |
| Refreshing | Pull-to-refresh indicator (§2.7) |

### 11.4 List Item Tap

- HapticFeedback.lightImpact() pada tap.
- Visual feedback: opacity 0.8 saat pressed (200ms).
- Pakai `InkWell` (Android ripple) atau `CupertinoButton.tinted` (iOS) — atau wrap di `Material` + `InkWell` untuk consistency.

---

## 12. Safe Area & Insets

### 12.1 Aturan

- **Setiap page top-level** wajib wrapped di `SafeArea` (langsung di bawah `Scaffold`).
- **Kecuali** page yang memang punya full-bleed image (e.g., server banner di ServerDetailPage) — pakai `SafeArea(top: false)` untuk header, manual handle bottom.

```dart
Scaffold(
  body: SafeArea(
    child: ListView(...),
  ),
);
```

### 12.2 Keyboard Avoidance

- Scaffold `resizeToAvoidBottomInset: true` (default).
- Pakai `SingleChildScrollView` di form panjang untuk scroll keyboard-aware.
- `MediaQuery.viewInsets.bottom` untuk dapat keyboard height kalau perlu custom.

### 12.3 Bottom Gesture Area (iOS)

iOS gesture bar = bottom 34px. Jangan place tap-critical UI di sini.

Tab bar default sudah handle ini (Material `BottomNavigationBar` + Cupertino `CupertinoTabBar` adaptive). Kalau custom bottom bar, tambahkan `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewPadding.bottom))`.

### 12.4 Notch / Dynamic Island (iOS) + Cutout (Android)

- `SafeArea` auto-handle. Jangan implement manual padding berdasarkan device model.
- Untuk full-bleed image header, pakai `SystemUiOverlayStyle` set status bar transparent + extend body behind.

---

## 13. Animation Timing

### 13.1 Standar Durasi

| Action | Duration | Curve |
|---|---|---|
| Tap feedback (button scale) | 150ms | easeOut |
| Page transition | 250ms iOS / 200ms Android | platform default |
| Sheet enter | 300ms | easeOutCubic |
| Sheet exit | 200ms | easeInCubic |
| Toast enter | 250ms | easeOutCubic |
| Toast exit | 200ms | easeInCubic |
| Skeleton shimmer | 1500ms loop | linear |
| Error shake | 300ms (2 bounce × 8px) | easeInOut |
| Color transition (toggle) | 200ms | easeInOut |
| Pull-to-refresh trigger | 200ms | easeOut |

### 13.2 Anti-Patterns Animation

- Durasi > 400ms untuk feedback minor (annoying, feel laggy).
- Animation kompleks (parallax, multi-stage) di list item yang ratusan — perf killer.
- Bouncy curve (`elasticOut`) untuk action yang sering — distracting.
- Ignore `MediaQuery.disableAnimations` — wajib respect (`MediaQuery.of(context).disableAnimations`).

---

## 14. Accessibility

### 14.1 Touch Target

- Min **44×44 px** untuk semua interactive element.
- Gap min 8px antara adjacent touch target.

### 14.2 Color Contrast

- Text on background: min 4.5:1 (WCAG AA).
- Large text (>18px or bold >14px): min 3:1.
- Cek dengan `https://webaim.org/resources/contrastchecker/`.

### 14.3 Semantics

- Setiap icon button wajib punya `tooltip` atau wrap di `Semantics(label: '...')`.
- Avatar dengan name wajib alt text.
- Form input wajib label visible (jangan hanya placeholder).

```dart
IconButton(
  icon: const Icon(LucideIcons.heart),
  tooltip: 'Suka',
  onPressed: ...,
);
```

### 14.4 Focus Order

- Tab order = visual order (top-to-bottom, left-to-right).
- Form: pakai `FocusNode` + `TextInputAction.next` untuk auto-jump.

### 14.5 Reduced Motion

```dart
final disableAnimations = MediaQuery.of(context).disableAnimations;
final duration = disableAnimations ? Duration.zero : AppMotion.medium;
```

---

## 15. Image Loading

### 15.1 Network Image

Selalu pakai `cached_network_image`:

```dart
CachedNetworkImage(
  imageUrl: post.imageUrl,
  placeholder: (_, __) => const VSkeleton(),
  errorWidget: (_, __, ___) => Container(
    color: AppColors.surface,
    child: const Icon(LucideIcons.imageOff, color: AppColors.textTertiary),
  ),
  fit: BoxFit.cover,
);
```

### 15.2 Avatar

```dart
VAvatar(
  url: user.avatarUrl,
  fallbackInitial: user.fullname[0].toUpperCase(),
  size: VAvatarSize.md,
);
```

Fallback: kalau `url` null/error → tampilkan inisial di lingkaran berwarna `AppColors.primarySoft` text `AppColors.primary`.

### 15.3 Image Upload Compression

Sebelum upload (avatar, banner, post image):

- Resize: max dimension 1920px (untuk post), 512px (untuk avatar).
- Quality: JPEG 80%.
- Pakai `package:image` (built-in di Flutter ecosystem).

---

## 16. Haptic Feedback

| Action | Haptic |
|---|---|
| Button tap (primary) | `HapticFeedback.lightImpact()` |
| Toggle on/off (like, follow) | `HapticFeedback.selectionClick()` |
| Long press menu open | `HapticFeedback.mediumImpact()` |
| Pull-to-refresh trigger | `HapticFeedback.mediumImpact()` |
| Error / invalid action | `HapticFeedback.heavyImpact()` |
| Success critical action | `HapticFeedback.mediumImpact()` + sound? (skip sound, gangguin) |

**JANGAN** trigger haptic untuk:
- Scroll (annoying).
- Every keystroke.
- Animation tick.

---

## 17. Anti-Patterns (Don'ts)

### 17.1 Loading

- Skeleton + spinner overlay bersamaan (pilih satu).
- Pull-to-refresh DAN button refresh DAN auto-refresh — overkill.
- Loading state tanpa min duration → flash, feel buggy.
- Spinner di mutation tanpa disable button → user double-submit.

### 17.2 Toast

- Toast untuk validation error (pakai inline `VFieldError`).
- Toast untuk konfirmasi destruktif (pakai `AlertDialog`).
- Toast dengan pesan teknis raw (translate ke human-friendly).
- Stack 5+ toast (max 3, replace oldest).

### 17.3 Dialog

- Dialog untuk non-decision (pakai toast atau snackbar).
- Dialog dengan 3+ button (pilih 2 max, atau pakai bottom sheet).
- Dialog yang block keyboard input untuk input field — pakai full page.

### 17.4 Button

- Stack 3+ primary button (pilih satu primary).
- Loading state yang user bisa tap berkali-kali.
- Disable tanpa visual hint kenapa.

### 17.5 Navigation

- Push 5+ level deep tanpa breadcrumb.
- Replace di tengah flow yang user expect back.
- Disable swipe-back gesture iOS tanpa alasan kuat.

### 17.6 Form

- Validation error muncul saat user pertama focus.
- Submit button stay enabled saat form clearly invalid.
- Error message panjang multi-paragraph (pakai modal/sheet).

### 17.7 List

- Re-fetch full list saat user kembali ke page (pakai cache + pull-to-refresh).
- No empty state — page kosong terlihat broken.
- No error state retry — user stuck.

### 17.8 Animation

- Animation > 400ms untuk feedback minor.
- Bouncy curve untuk action sering.
- Ignore `disableAnimations` accessibility setting.

### 17.9 Safe Area

- Hardcode padding top berdasarkan device model.
- Lupa wrap di `SafeArea` → konten di belakang notch.
- Tab bar tanpa bottom inset → konten di belakang gesture bar.

---

## 18. Component Inventory (Implementation Checklist)

| Component | Location | Status | Notes |
|---|---|---|---|
| `VButton` | `core/widgets/v_button.dart` | **Done (Phase 0)** | 5 variants × 3 sizes, loading state, haptic feedback |
| `VInput` | `core/widgets/v_input.dart` | **Done (Phase 0)** | TextFormField wrapper, obscure toggle, error icon |
| `VAvatar` | `core/widgets/v_avatar.dart` | **Done (Phase 0)** | 5 sizes (xs/sm/md/lg/xl), URL + fallback initial circle |
| `VAppBar` | `core/widgets/v_app_bar.dart` | **Done (Phase 0)** | Leading (back/close/none) + title + actions + bottom border, PreferredSizeWidget |
| `VToast` | `core/feedback/toast/v_toast.dart` | **Done (Phase 0)** | 4 types, max stack 3, Quasar spec parity (icon bubble, pill retry, error shake) |
| `VSkeleton` | `core/feedback/v_skeleton.dart` | **Done (Phase 0)** | Shimmer via `shimmer` package, circle variant |
| `VProgressRing` | `core/feedback/v_progress_ring.dart` | **Done (Phase 0)** | inline + overlay mode, % label |
| `VFieldError` | `core/feedback/v_field_error.dart` | **Done (Phase 0)** | Inline non-input error with alert icon |
| `VEmptyState` | `core/feedback/v_empty_state.dart` | **Done (Phase 0)** | icon + title + sub + optional CTA |
| `PostCard` | `features/post/presentation/widgets/` | TODO Phase 4 | Feed item |
| `ServerCard` | `features/server/presentation/widgets/` | TODO Phase 3 | Discovery item |
| `CommentTile` | `features/post/presentation/widgets/` | TODO Phase 4 | |

---

## 19. Reference

- `MIGRATION_QUASAR_TO_FLUTTER.md` — parent migration plan.
- `virdan/virdan-reference-ui/` — visual mockup reference.
- `virdanmobileapp-quasar/src/components/feedback/` — existing implementation (port to Flutter).
- `virdanmobileapp-quasar/src/css/feedback-animations.scss` — animation reference.
- Material 3 guidelines: https://m3.material.io
- Apple HIG: https://developer.apple.com/design/human-interface-guidelines
- Flutter UI patterns: https://docs.flutter.dev/ui

---

_Last updated: 2026-05-24_
_Doc version: 1.0.0_
