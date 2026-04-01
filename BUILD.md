# Virdan Mobile App - Panduan Build APK

Dokumen ini berisi langkah-langkah untuk membangun (build) aplikasi Virdan Mobile ke format APK (Android).

## 📋 Prasyarat (Prerequisites)

1. **Java JDK**: Gunakan OpenJDK 21 (sudah terpasang di sistem).
2. **Android SDK**: Pastikan terinstal di `~/Android/Sdk`.
3. **Node.js & NPM**: Versi terbaru (v22.x).
4. **Capacitor CLI**: Sudah terpasang sebagai dev-dependency.

---

## 🛠️ Konsep Dasar (Setup Sekali Saja)

Tambahkan konfigurasi environment di file `~/.bashrc` Anda:

```bash
# Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin

# Capacitor Android Studio Path (Khusus Snap)
export CAPACITOR_ANDROID_STUDIO_PATH="/snap/android-studio/current/bin/studio.sh"
```

Setelah itu jalankan `source ~/.bashrc`.

---

## 🚀 Langkah-Langkah Build APK

### 1. Update Konfigurasi API

Pastikan `src/environments/environment.ts` menggunakan URL yang bisa diakses oleh HP (misalnya menggunakan URL **ngrok** atau IP Lokal).

### 2. Build Aset Web

Jalankan perintah ini untuk membangun file Angular:

```bash
npm run build
```

### 3. Sinkronisasi ke Platform Android

Pindahkan aset web ke dalam project Android:

```bash
npx cap sync android
```

### 4. Proses Build APK

#### Opsi A: Lewat Terminal (Direkomendasikan)

Jalankan perintah ini untuk membangun APK secara langsung:

```bash
cd android && ./gradlew assembleDebug
```

**Lokasi File APK:**
`android/app/build/outputs/apk/debug/app-debug.apk`

#### Opsi B: Lewat Android Studio

1. Buka project: `npx cap open android`
2. Tunggu Gradle Sync selesai.
3. Klik menu **Build > Build Bundle(s) / APK(s) > Build APK(s)**.

---

## 📝 Catatan Penting

- Jangan lupa nyalakan **ngrok** atau hubungkan laptop dan HP ke WiFi yang sama.
- Jika ada perubahan di kode Angular, Anda **HARUS** menjalankan `npm run build` dan `npx cap sync android` lagi sebelum melakukan build APK.
