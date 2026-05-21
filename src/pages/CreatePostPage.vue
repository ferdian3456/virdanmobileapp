<template>
  <q-page class="cp-page">
    <!-- Top bar -->
    <header class="cp-header">
      <button class="cp-link" type="button" aria-label="Back" @click="onCancel">
        <ChevronLeft :size="24" :stroke-width="2" />
      </button>
      <h1 class="cp-title">{{ headerTitle }}</h1>

      <button
        v-if="step === 'crop'"
        class="cp-link primary"
        type="button"
        :disabled="!sourceImage || isProcessing"
        @click="commitCrop"
      >
        Next
      </button>
      <span v-else class="cp-spacer"></span>
    </header>

    <!-- ─── Step 1: source picker ──────────────────────────── -->
    <section v-if="step === 'source'" class="source-section">
      <!-- Gallery tab: tap area with optional drag-drop -->
      <div
        v-show="sourceTab === 'gallery'"
        class="gallery-stage"
        :class="{ 'drag-over': isDragOver }"
        @click="pickFromGallery"
        @dragover.prevent="isDragOver = true"
        @dragleave.prevent="isDragOver = false"
        @drop.prevent="onDrop"
      >
        <div class="gallery-cta">
          <ImageIcon :size="44" :stroke-width="1.4" class="gallery-cta-icon" />
          <span class="gallery-cta-title">Tap to choose a photo</span>
          <span class="gallery-cta-help">JPEG, PNG, or WebP — max {{ MAX_FILE_SIZE_MB }}MB</span>
        </div>
      </div>

      <!-- Photo tab: live camera viewfinder via getUserMedia -->
      <div v-show="sourceTab === 'photo'" class="camera-stage">
        <video
          ref="videoEl"
          autoplay
          playsinline
          muted
          class="camera-video"
        ></video>

        <!-- Corner brackets overlay -->
        <div class="camera-corners">
          <span class="camera-corner camera-corner-tl"></span>
          <span class="camera-corner camera-corner-tr"></span>
          <span class="camera-corner camera-corner-bl"></span>
          <span class="camera-corner camera-corner-br"></span>
        </div>

        <!-- Error overlay -->
        <div v-if="cameraError" class="camera-error-overlay">
          <CameraOff :size="36" />
          <p class="camera-error-text">{{ cameraError }}</p>
          <button class="camera-error-btn" type="button" @click="pickFromCameraInput">
            Use device camera instead
          </button>
        </div>

        <!-- Camera controls -->
        <div class="camera-controls">
          <button
            class="camera-side-btn"
            type="button"
            aria-label="Pick from gallery"
            @click="pickFromGallery"
          >
            <ImageIcon :size="20" />
          </button>

          <button
            class="camera-shutter"
            type="button"
            aria-label="Capture"
            :disabled="!cameraReady || isCapturing"
            @click="captureFrame"
          >
            <span class="shutter-inner"></span>
          </button>

          <button
            class="camera-side-btn"
            type="button"
            aria-label="Switch camera"
            :disabled="!cameraReady || cameraSwitching"
            @click="flipCamera"
          >
            <RefreshCw :size="20" />
          </button>
        </div>
      </div>

      <!-- Video coming-soon panel -->
      <div v-show="sourceTab === 'video'" class="video-stage">
        <Video :size="44" :stroke-width="1.4" />
        <p class="video-stage-text">Video posts coming soon</p>
      </div>

      <!-- Bottom 3-tab strip -->
      <div class="source-tabs">
        <button
          v-for="t in sourceTabs"
          :key="t.id"
          type="button"
          class="source-tab"
          :class="{ active: sourceTab === t.id }"
          @click="sourceTab = t.id"
        >
          {{ t.label }}
        </button>
      </div>

      <input
        ref="galleryInput"
        type="file"
        accept="image/jpeg,image/png,image/webp"
        class="hidden-input"
        @change="onFileSelected"
      />
      <input
        ref="cameraInput"
        type="file"
        accept="image/*"
        capture="environment"
        class="hidden-input"
        @change="onFileSelected"
      />
    </section>

    <!-- ─── Step 2: crop ─────────────────────────────────────── -->
    <section v-else-if="step === 'crop' && sourceImage" class="crop-section">
      <div ref="stageRef" class="crop-stage" :style="stageStyle">
        <div
          class="crop-image"
          :style="imageStyle"
          @pointerdown="onPointerDown"
        ></div>
        <div class="crop-frame-overlay" :style="frameStyle">
          <div class="crop-frame-grid"></div>
        </div>
      </div>

      <!-- Zoom slider -->
      <div class="zoom-row">
        <ZoomOut :size="16" class="zoom-icon" />
        <q-slider
          v-model="zoom"
          :min="ZOOM_MIN"
          :max="ZOOM_MAX"
          :step="0.01"
          color="white"
          track-color="grey-8"
          class="zoom-slider"
          @update:model-value="onZoomChange"
        />
        <ZoomIn :size="16" class="zoom-icon" />
      </div>

      <!-- Aspect chips -->
      <div class="aspect-strip">
        <button
          v-for="ar in ASPECT_RATIOS"
          :key="ar.id"
          type="button"
          class="aspect-chip"
          :class="{ active: selectedAspectId === ar.id }"
          @click="changeAspect(ar.id)"
        >
          {{ ar.label }}
        </button>
      </div>
    </section>

    <!-- ─── Step 3: detail ───────────────────────────────────── -->
    <section v-else-if="step === 'detail'" class="detail-section">
      <!-- Thumbnail centered -->
      <div class="detail-thumb-wrap">
        <img v-if="croppedDataUrl" :src="croppedDataUrl" alt="" class="detail-thumb" />
      </div>

      <!-- Caption -->
      <div class="caption-wrap">
        <textarea
          v-model="caption"
          class="caption-textarea-light"
          placeholder="Write a caption…"
          rows="4"
          maxlength="2200"
        ></textarea>
        <div class="caption-counter" :class="{ warn: caption.length > 2100 }">
          {{ caption.length }}/2200
        </div>
      </div>

      <!-- Mock rows -->
      <div class="meta-rows">
        <button class="meta-row" type="button" disabled>
          <Users :size="20" class="meta-icon" />
          <span class="meta-label">Tag people</span>
          <ChevronRight :size="18" class="meta-chev" />
        </button>
        <button class="meta-row" type="button" disabled>
          <MapPin :size="20" class="meta-icon" />
          <span class="meta-label">Add location</span>
          <ChevronRight :size="18" class="meta-chev" />
        </button>
        <button class="meta-row" type="button" disabled>
          <Music :size="20" class="meta-icon" />
          <span class="meta-label">Add music</span>
          <ChevronRight :size="18" class="meta-chev" />
        </button>
      </div>

      <!-- Toggles (UI placeholders — BE not yet wired) -->
      <div class="toggle-rows">
        <div class="toggle-row">
          <div class="toggle-text">
            <div class="toggle-title">Post to other servers</div>
            <div class="toggle-help">Share to multiple servers at once</div>
          </div>
          <q-toggle v-model="opts.crossPost" color="primary" disable />
        </div>
        <div class="toggle-row">
          <div class="toggle-text">
            <div class="toggle-title">Hide like count</div>
            <div class="toggle-help">Only you can see how many likes this post gets</div>
          </div>
          <q-toggle v-model="opts.hideLikes" color="primary" disable />
        </div>
        <div class="toggle-row">
          <div class="toggle-text">
            <div class="toggle-title">Turn off commenting</div>
            <div class="toggle-help">Members can't comment on this post</div>
          </div>
          <q-toggle v-model="opts.disableComments" color="primary" disable />
        </div>
      </div>

      <div class="server-info">
        <span class="server-info-label">POSTING TO</span>
        <span class="server-info-value">{{ activeServer?.name ?? 'No server selected' }}</span>
      </div>
    </section>

    <!-- Floating submit button (detail step only) -->
    <footer v-if="step === 'detail'" class="cp-footer">
      <q-btn
        unelevated
        no-caps
        color="primary"
        :label="isUploading ? 'Sharing…' : 'Post'"
        class="full-width cp-post-btn"
        :disable="!canPost"
        :loading="isUploading"
        @click="submit"
      />
    </footer>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onBeforeUnmount, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import {
  ChevronLeft, ChevronRight, Image as ImageIcon, CameraOff, Video,
  ZoomIn, ZoomOut, Users, MapPin, Music, RefreshCw,
} from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import { api } from 'src/boot/axios';
import { useAppStore } from 'src/stores/app.store';
import { useToast } from 'src/composables/useToast';
import { apiErrorToast } from 'src/composables/useApiError';
import {
  ASPECT_RATIOS, ZOOM_MIN, ZOOM_MAX,
  computeCoverFit, clamp,
  renderCrop, blobToDataUrl, fileToImage,
  type FitResult,
} from 'src/composables/useImageCrop';

type Step = 'source' | 'crop' | 'detail';
type AspectId = 'free' | '1:1' | '4:5' | '9:16' | '16:9';
type SourceTab = 'gallery' | 'photo' | 'video';

const sourceTabs: { id: SourceTab; label: string }[] = [
  { id: 'gallery', label: 'Gallery' },
  { id: 'photo', label: 'Photo' },
  { id: 'video', label: 'Video' },
];

const sourceTab = ref<SourceTab>('gallery');

/* ─── Live camera state (getUserMedia) ──────────────────── */
const videoEl = ref<HTMLVideoElement | null>(null);
const cameraStream = ref<MediaStream | null>(null);
const cameraError = ref('');
const cameraReady = ref(false);
const cameraSwitching = ref(false);
const isCapturing = ref(false);
const facingMode = ref<'environment' | 'user'>('environment');
const isDragOver = ref(false);

const ALLOWED_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const MAX_FILE_SIZE_MB = 10;

const router = useRouter();
const appStore = useAppStore();
const { activeServer } = storeToRefs(appStore);
const toast = useToast();

const step = ref<Step>('source');
const galleryInput = ref<HTMLInputElement | null>(null);
const cameraInput = ref<HTMLInputElement | null>(null);
const stageRef = ref<HTMLDivElement | null>(null);

const sourceImage = ref<HTMLImageElement | null>(null);
const sourceObjectUrl = ref<string | null>(null);
const selectedAspectId = ref<AspectId>('1:1');

const stageWidth = ref(0);
const frameWidth = ref(0);
const frameHeight = ref(0);
const baseFit = ref<FitResult | null>(null);
const zoom = ref(1);

const tx = ref(0);
const ty = ref(0);

const isProcessing = ref(false);
const isUploading = ref(false);
const croppedBlob = ref<Blob | null>(null);
const croppedDataUrl = ref<string | null>(null);
const caption = ref('');

const opts = ref({ crossPost: false, hideLikes: false, disableComments: false });

const headerTitle = computed(() => {
  if (step.value === 'crop') return 'Crop';
  if (step.value === 'detail') return 'Detail';
  return 'New Post';
});

const canPost = computed(
  () => !!croppedBlob.value && caption.value.trim().length > 0 && !!activeServer.value
);

const displayDims = computed(() => {
  if (!baseFit.value) return null;
  return {
    w: baseFit.value.displayWidth * zoom.value,
    h: baseFit.value.displayHeight * zoom.value,
  };
});

const dragBounds = computed(() => {
  if (!displayDims.value) return null;
  const overflowX = displayDims.value.w - frameWidth.value;
  const overflowY = displayDims.value.h - frameHeight.value;
  return {
    minTx: -overflowX,
    minTy: -overflowY,
    maxTx: 0,
    maxTy: 0,
  };
});

const stageStyle = computed(() => ({
  width: `${stageWidth.value}px`,
  height: `${frameHeight.value}px`,
}));

const frameStyle = computed(() => ({
  width: `${frameWidth.value}px`,
  height: `${frameHeight.value}px`,
}));

const imageStyle = computed(() => {
  if (!displayDims.value || !sourceObjectUrl.value) return {};
  return {
    width: `${displayDims.value.w}px`,
    height: `${displayDims.value.h}px`,
    transform: `translate(${tx.value}px, ${ty.value}px)`,
    backgroundImage: `url(${sourceObjectUrl.value})`,
  };
});

/* ─── Lifecycle ─────────────────────────────────────────────── */
onMounted(() => window.addEventListener('resize', recalcStage));
onBeforeUnmount(() => {
  window.removeEventListener('resize', recalcStage);
  if (sourceObjectUrl.value) URL.revokeObjectURL(sourceObjectUrl.value);
  stopCamera();
});

/* Watch source tab — start/stop camera as it gains/loses focus. */
watch(sourceTab, (next, prev) => {
  if (next === 'photo' && step.value === 'source') void startCamera();
  if (prev === 'photo') stopCamera();
});

/* When user moves to crop/detail, free the camera. */
watch(step, (next) => {
  if (next !== 'source') stopCamera();
});

/* ─── Camera (getUserMedia) ─────────────────────────────────── */
async function startCamera() {
  if (!navigator.mediaDevices?.getUserMedia) {
    cameraError.value =
      "Live camera isn't supported in this browser. Use the gallery picker instead.";
    return;
  }
  cameraError.value = '';
  cameraReady.value = false;
  stopCamera();

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: facingMode.value },
      audio: false,
    });
    cameraStream.value = stream;
    if (videoEl.value) {
      videoEl.value.srcObject = stream;
      await videoEl.value.play().catch(() => undefined);
    }
    cameraReady.value = true;
  } catch (err) {
    const code = (err as DOMException)?.name;
    if (code === 'NotAllowedError' || code === 'PermissionDeniedError') {
      cameraError.value = 'Camera permission denied.';
    } else if (code === 'NotFoundError' || code === 'OverconstrainedError') {
      cameraError.value = 'No camera available on this device.';
    } else {
      cameraError.value = 'Could not start camera.';
    }
  }
}

function stopCamera() {
  if (cameraStream.value) {
    cameraStream.value.getTracks().forEach((t) => t.stop());
    cameraStream.value = null;
  }
  if (videoEl.value) videoEl.value.srcObject = null;
  cameraReady.value = false;
}

async function flipCamera() {
  if (cameraSwitching.value) return;
  cameraSwitching.value = true;
  facingMode.value = facingMode.value === 'environment' ? 'user' : 'environment';
  try {
    await startCamera();
  } finally {
    cameraSwitching.value = false;
  }
}

async function captureFrame() {
  const v = videoEl.value;
  if (!v || !cameraReady.value || isCapturing.value) return;
  if (!v.videoWidth || !v.videoHeight) return;

  isCapturing.value = true;
  try {
    const canvas = document.createElement('canvas');
    canvas.width = v.videoWidth;
    canvas.height = v.videoHeight;
    const ctx = canvas.getContext('2d');
    if (!ctx) {
      toast.error({ title: 'Failed to capture frame.' });
      return;
    }
    ctx.drawImage(v, 0, 0, canvas.width, canvas.height);

    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob((b) => resolve(b), 'image/jpeg', 0.92)
    );
    if (!blob) {
      toast.error({ title: 'Failed to encode capture.' });
      return;
    }
    const file = new File([blob], 'capture.jpg', { type: 'image/jpeg' });
    stopCamera();
    await loadFile(file);
  } finally {
    isCapturing.value = false;
  }
}

/* Fallback: open OS camera via file input when getUserMedia is unavailable. */
function pickFromCameraInput() {
  cameraInput.value?.click();
}

/* Drag-and-drop support on the Gallery tap area. */
async function onDrop(event: DragEvent) {
  isDragOver.value = false;
  const file = event.dataTransfer?.files?.[0];
  if (file) await loadFile(file);
}

/* ─── Step 1: source picker ─────────────────────────────────── */
function pickFromGallery() {
  galleryInput.value?.click();
}

async function onFileSelected(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;
  await loadFile(file);
  input.value = '';
}

async function loadFile(file: File) {
  if (!ALLOWED_TYPES.includes(file.type)) {
    toast.error({ title: 'Unsupported format. Use JPEG, PNG, or WebP.' });
    return;
  }
  const sizeMB = file.size / (1024 * 1024);
  if (sizeMB > MAX_FILE_SIZE_MB) {
    toast.error({ title: `Image must be smaller than ${MAX_FILE_SIZE_MB}MB.` });
    return;
  }

  if (sourceObjectUrl.value) URL.revokeObjectURL(sourceObjectUrl.value);

  try {
    const img = await fileToImage(file);
    sourceImage.value = img;
    sourceObjectUrl.value = img.src;
    step.value = 'crop';
    selectedAspectId.value = '1:1';
    zoom.value = 1;
    await nextTick();
    recalcStage();
  } catch {
    toast.error({ title: 'Could not read image.' });
  }
}

/* ─── Step 2: crop ──────────────────────────────────────────── */
function recalcStage() {
  const stage = stageRef.value;
  if (!stage || !sourceImage.value) return;

  const w = stage.parentElement?.clientWidth ?? stage.clientWidth ?? 0;
  stageWidth.value = w;
  frameWidth.value = w;

  const aspectRatio = aspectValue();
  if (aspectRatio === null) {
    // Free — use square crop frame as default visual.
    frameHeight.value = w;
  } else {
    frameHeight.value = Math.round(w / aspectRatio);
  }

  const f = computeCoverFit(
    sourceImage.value.naturalWidth,
    sourceImage.value.naturalHeight,
    frameWidth.value,
    frameHeight.value
  );
  baseFit.value = f;
  // Center inside frame using zoomed dimensions.
  if (displayDims.value) {
    tx.value = (frameWidth.value - displayDims.value.w) / 2;
    ty.value = (frameHeight.value - displayDims.value.h) / 2;
  }
}

function aspectValue(): number | null {
  if (selectedAspectId.value === 'free') return null;
  return ASPECT_RATIOS.find((a) => a.id === selectedAspectId.value)?.ratio ?? 1;
}

function changeAspect(id: string) {
  selectedAspectId.value = id as AspectId;
  zoom.value = 1;
  recalcStage();
}

function onZoomChange() {
  if (!dragBounds.value) return;
  tx.value = clamp(tx.value, dragBounds.value.minTx, dragBounds.value.maxTx);
  ty.value = clamp(ty.value, dragBounds.value.minTy, dragBounds.value.maxTy);
}

/* Drag handling */
let dragStartX = 0;
let dragStartY = 0;
let dragOriginTx = 0;
let dragOriginTy = 0;
let dragging = false;

function onPointerDown(e: PointerEvent) {
  if (!dragBounds.value) return;
  dragging = true;
  dragStartX = e.clientX;
  dragStartY = e.clientY;
  dragOriginTx = tx.value;
  dragOriginTy = ty.value;
  (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);

  window.addEventListener('pointermove', onPointerMove);
  window.addEventListener('pointerup', onPointerUp);
  window.addEventListener('pointercancel', onPointerUp);
}

function onPointerMove(e: PointerEvent) {
  if (!dragging || !dragBounds.value) return;
  const dx = e.clientX - dragStartX;
  const dy = e.clientY - dragStartY;
  tx.value = clamp(dragOriginTx + dx, dragBounds.value.minTx, dragBounds.value.maxTx);
  ty.value = clamp(dragOriginTy + dy, dragBounds.value.minTy, dragBounds.value.maxTy);
}

function onPointerUp() {
  dragging = false;
  window.removeEventListener('pointermove', onPointerMove);
  window.removeEventListener('pointerup', onPointerUp);
  window.removeEventListener('pointercancel', onPointerUp);
}

/* Step 2 → 3: produce blob */
async function commitCrop() {
  if (!sourceImage.value || !displayDims.value || isProcessing.value) return;
  isProcessing.value = true;
  try {
    const blob = await renderCrop({
      image: sourceImage.value,
      frameWidth: frameWidth.value,
      frameHeight: frameHeight.value,
      displayWidth: displayDims.value.w,
      displayHeight: displayDims.value.h,
      translateX: tx.value,
      translateY: ty.value,
      outputMaxWidth: 1080,
      outputType: 'image/webp',
      outputQuality: 0.9,
    });
    croppedBlob.value = blob;
    croppedDataUrl.value = await blobToDataUrl(blob);
    step.value = 'detail';
  } catch {
    toast.error({ title: 'Failed to crop image.' });
  } finally {
    isProcessing.value = false;
  }
}

/* ─── Step 3: post ──────────────────────────────────────────── */
async function submit() {
  if (!canPost.value || isUploading.value) return;
  if (!activeServer.value) {
    toast.error({ title: 'No active server selected.' });
    return;
  }

  isUploading.value = true;
  try {
    const fd = new FormData();
    fd.append('caption', caption.value.trim());
    fd.append('image', croppedBlob.value as Blob, 'post.webp');

    await api.post(`/servers/${activeServer.value.id}/posts`, fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });

    toast.success({ title: 'Post shared.' });
    await router.push({ name: 'home' });
  } catch (err) {
    toast.error(apiErrorToast(err));
  } finally {
    isUploading.value = false;
  }
}

/* ─── Header back / cancel ─────────────────────────────────── */
function onCancel() {
  if (step.value === 'detail') {
    step.value = 'crop';
    return;
  }
  if (step.value === 'crop') {
    step.value = 'source';
    if (sourceObjectUrl.value) URL.revokeObjectURL(sourceObjectUrl.value);
    sourceObjectUrl.value = null;
    sourceImage.value = null;
    return;
  }
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'home' });
}
</script>

<style lang="scss" scoped>
.cp-page {
  min-height: 100dvh;
  background: #fff;
  color: #212529;
  display: flex;
  flex-direction: column;
  padding-bottom: 88px;
}

.cp-header {
  position: sticky;
  top: 0;
  z-index: 5;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
  background: #fff;
  border-bottom: 1px solid #F1F3F5;
  padding-top: env(safe-area-inset-top, 0px);
}

.cp-link {
  background: transparent;
  border: 0;
  font-family: inherit;
  font-size: 15px;
  font-weight: 500;
  cursor: pointer;
  padding: 8px 0;
  color: #212529;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  min-width: 56px;

  &.primary {
    color: #007BFF;
    font-weight: 600;
    justify-content: flex-end;

    &:disabled {
      color: #ADB5BD;
      cursor: default;
    }
  }
}

.cp-spacer {
  width: 56px;
}

.cp-title {
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #0F172A;
  flex: 1;
  text-align: center;
}

/* ── Step 1: source picker ──────────────────────────────────── */
.source-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  background: #fff;
}

/* Gallery tap area */
.gallery-stage {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #F8F9FA;
  margin: 16px;
  border-radius: 18px;
  border: 1.5px dashed #DEE2E6;
  cursor: pointer;
  transition: border-color 0.15s ease, background 0.15s ease;
  min-height: 360px;

  &:hover,
  &.drag-over {
    border-color: #007BFF;
    background: #E7F1FF;
  }
}

.gallery-cta {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 32px;
  text-align: center;
}

.gallery-cta-icon {
  color: #6C757D;
}

.gallery-cta-title {
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  color: #0F172A;
}

.gallery-cta-help {
  font-size: 12px;
  color: #6C757D;
}

/* Live camera viewfinder — light theme */
.camera-stage {
  position: relative;
  flex: 1;
  background: #fff;
  overflow: hidden;
  min-height: 480px;
}

.camera-video {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 110px;
  width: 100%;
  height: calc(100% - 110px);
  object-fit: cover;
  background: #F8F9FA;
}

.camera-corners {
  position: absolute;
  top: 24px;
  right: 24px;
  bottom: 134px;
  left: 24px;
  pointer-events: none;
}

.camera-corner {
  position: absolute;
  width: 26px;
  height: 26px;
  border-color: #495057;
  border-style: solid;
}

.camera-corner-tl { top: 0; left: 0; border-width: 2.5px 0 0 2.5px; }
.camera-corner-tr { top: 0; right: 0; border-width: 2.5px 2.5px 0 0; }
.camera-corner-bl { bottom: 0; left: 0; border-width: 0 0 2.5px 2.5px; }
.camera-corner-br { bottom: 0; right: 0; border-width: 0 2.5px 2.5px 0; }

.camera-error-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 110px;
  background: #F8F9FA;
  color: #495057;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 24px;
  text-align: center;
}

.camera-error-text {
  font-size: 14px;
  margin: 0;
  max-width: 260px;
  line-height: 1.4;
  color: #495057;
}

.camera-error-btn {
  background: #007BFF;
  color: #fff;
  border: 0;
  border-radius: 999px;
  padding: 8px 18px;
  font-family: inherit;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}

.camera-controls {
  position: absolute;
  bottom: 24px;
  left: 0;
  right: 0;
  display: flex;
  align-items: center;
  justify-content: space-around;
  padding: 0 32px;
}

.camera-side-btn {
  background: #F1F3F5;
  border: 0;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  color: #495057;

  &:hover:not(:disabled) {
    background: #E9ECEF;
  }

  &:disabled {
    cursor: default;
    opacity: 0.4;
  }
}

.camera-shutter {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: #fff;
  border: 3px solid #0F172A;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  padding: 0;

  &:disabled {
    opacity: 0.55;
    cursor: default;
  }

  .shutter-inner {
    display: none;
  }

  &:hover:not(:disabled) {
    background: #F1F3F5;
  }
}

/* Video coming-soon panel */
.video-stage {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
  background: #fff;
  color: #ADB5BD;
  min-height: 360px;
}

.video-stage-text {
  margin: 0;
  font-size: 14px;
  color: #6C757D;
}

/* Bottom source tabs */
.source-tabs {
  position: sticky;
  bottom: 0;
  background: #fff;
  border-top: 1px solid #F1F3F5;
  display: flex;
  justify-content: space-around;
  padding: 12px 16px;
}

.source-tab {
  background: transparent;
  border: 0;
  font-family: inherit;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
  color: #ADB5BD;
  cursor: pointer;
  text-transform: uppercase;
  padding: 4px 8px;
  position: relative;

  &.active {
    color: #0F172A;

    &::after {
      content: '';
      position: absolute;
      left: 50%;
      bottom: -8px;
      transform: translateX(-50%);
      width: 4px;
      height: 4px;
      border-radius: 50%;
      background: #007BFF;
    }
  }

  &.disabled {
    color: #DEE2E6;
    cursor: not-allowed;
  }
}

.hidden-input {
  display: none;
}

/* ── Step 2: crop ───────────────────────────────────────────── */
.crop-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  background: #fff;
}

.crop-stage {
  position: relative;
  background: #F1F3F5;
  margin: 0 auto;
  overflow: hidden;
  width: 100%;
  touch-action: none;
}

.crop-image {
  position: absolute;
  inset: 0;
  background-size: cover;
  background-position: 0 0;
  cursor: grab;

  &:active {
    cursor: grabbing;
  }
}

.crop-frame-overlay {
  position: absolute;
  left: 0;
  top: 0;
  pointer-events: none;
  border: 1px solid rgba(15, 23, 42, 0.4);
}

.crop-frame-grid {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(to right, rgba(15, 23, 42, 0.18) 1px, transparent 1px),
    linear-gradient(to bottom, rgba(15, 23, 42, 0.18) 1px, transparent 1px);
  background-size: 33.33% 33.33%;
}

.zoom-row {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 16px 20px 8px;
}

.zoom-icon {
  color: #6C757D;
  flex-shrink: 0;
}

.zoom-slider {
  flex: 1;
}

.aspect-strip {
  display: flex;
  gap: 8px;
  padding: 8px 16px 16px;
  overflow-x: auto;
  width: 100%;
  justify-content: center;

  &::-webkit-scrollbar {
    display: none;
  }
}

.aspect-chip {
  background: #F1F3F5;
  color: #495057;
  border: 0;
  border-radius: 999px;
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  font-family: inherit;
  white-space: nowrap;

  &.active {
    background: #0F172A;
    color: #fff;
  }
}

/* ── Step 3: detail ─────────────────────────────────────────── */
.detail-section {
  flex: 1;
  background: #fff;
  padding: 16px 16px 120px; /* room for floating Post button */
}

.cp-footer {
  position: fixed;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 480px;
  background: rgba(255, 255, 255, 0.96);
  backdrop-filter: blur(8px);
  border-top: 1px solid #F1F3F5;
  padding: 12px 20px calc(env(safe-area-inset-bottom, 0px) + 16px);
  z-index: 10;
}

.cp-post-btn {
  border-radius: 14px !important;
  min-height: 48px;
  font-weight: 600;
  letter-spacing: -0.01em;
}

.detail-thumb-wrap {
  display: flex;
  justify-content: center;
  margin-bottom: 16px;
}

.detail-thumb {
  width: 88px;
  height: 88px;
  border-radius: 12px;
  object-fit: cover;
  background: #F1F3F5;
}

.caption-wrap {
  position: relative;
  margin-bottom: 24px;
  padding-bottom: 8px;
  border-bottom: 1px solid #F1F3F5;
}

.caption-textarea-light {
  width: 100%;
  background: transparent;
  color: #212529;
  border: 0;
  outline: none;
  resize: none;
  font-family: inherit;
  font-size: 15px;
  line-height: 1.5;
  letter-spacing: -0.01em;
  min-height: 96px;
  padding: 8px 0;

  &::placeholder {
    color: #ADB5BD;
  }
}

.caption-counter {
  font-size: 11px;
  color: #ADB5BD;
  text-align: right;

  &.warn {
    color: #FBBF24;
  }
}

.meta-rows {
  display: flex;
  flex-direction: column;
  border-top: 1px solid #F1F3F5;
  border-bottom: 1px solid #F1F3F5;
  margin-bottom: 16px;
}

.meta-row {
  background: transparent;
  border: 0;
  padding: 14px 4px;
  display: flex;
  align-items: center;
  gap: 14px;
  cursor: pointer;
  font-family: inherit;
  text-align: left;
  border-bottom: 1px solid #F8F9FA;

  &:last-child {
    border-bottom: 0;
  }

  &:disabled {
    cursor: default;
    opacity: 0.55;
  }
}

.meta-icon {
  color: #495057;
  flex-shrink: 0;
}

.meta-label {
  flex: 1;
  font-size: 14px;
  font-weight: 500;
  color: #212529;
}

.meta-chev {
  color: #ADB5BD;
}

.toggle-rows {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin-bottom: 24px;
}

.toggle-row {
  background: transparent;
  padding: 12px 4px;
  display: flex;
  align-items: center;
  gap: 16px;
}

.toggle-text {
  flex: 1;
  min-width: 0;
}

.toggle-title {
  font-size: 14px;
  font-weight: 600;
  color: #212529;
  letter-spacing: -0.01em;
}

.toggle-help {
  font-size: 12px;
  color: #6C757D;
  margin-top: 2px;
  line-height: 1.4;
}

.server-info {
  border-top: 1px solid #F1F3F5;
  padding-top: 12px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.server-info-label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.06em;
  color: #6C757D;
}

.server-info-value {
  font-size: 14px;
  font-weight: 500;
  color: #212529;
}
</style>
