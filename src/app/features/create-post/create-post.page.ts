import {
  Component,
  signal,
  computed,
  inject,
  ViewChild,
  ElementRef,
  NgZone,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import {
  IonContent,
  IonHeader,
  IonToolbar,
  IonButtons,
  IonButton,
  IonIcon,
  IonTitle,
  IonSpinner,
  ToastController,
} from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import {
  chevronBack,
  imageOutline,
  sendOutline,
  closeCircleOutline, cropOutline } from 'ionicons/icons';
import { StateService } from '../../core/services/state.service';
import { ApiService } from '../../core/services/api';

@Component({
  selector: 'app-create-post',
  templateUrl: './create-post.page.html',
  styleUrls: ['./create-post.page.scss'],
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    IonContent,
    IonHeader,
    IonToolbar,
    IonButtons,
    IonButton,
    IonIcon,
    IonTitle,
    IonSpinner,
  ],
})
export class CreatePostPage {
  @ViewChild('cropCanvas') cropCanvasRef!: ElementRef<HTMLCanvasElement>;
  @ViewChild('cropContainer') cropContainerRef!: ElementRef<HTMLDivElement>;
  @ViewChild(IonContent) content!: IonContent;

  caption = signal('');
  croppedDataUrl = signal<string | null>(null);
  croppedBlob = signal<Blob | null>(null);
  imageLoaded = signal(false);
  isSubmitting = signal(false);

  readonly MAX_CAPTION = 500;
  readonly ALLOWED_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
  readonly MAX_FILE_SIZE_MB = 5;
  readonly OUTPUT_SIZE = 512;

  captionLength = computed(() => this.caption().length);
  isNearLimit = computed(() => this.captionLength() > 450);
  canPost = computed(() => this.caption().trim().length > 0 && this.croppedBlob() !== null);

  private sourceImage = new Image();
  private canvasEl!: HTMLCanvasElement;
  private ctx!: CanvasRenderingContext2D;
  private cropX = 0;
  private cropY = 0;
  private cropSize = 0;
  private canvasDisplaySize = 0;
  private isDragging = false;
  private dragStartX = 0;
  private dragStartY = 0;
  private dragStartCropX = 0;
  private dragStartCropY = 0;

  // Cover-fit draw params
  private drawX = 0;
  private drawY = 0;
  private drawW = 0;
  private drawH = 0;

  private router = inject(Router);
  private api = inject(ApiService);
  private stateService = inject(StateService);
  private toastCtrl = inject(ToastController);
  private ngZone = inject(NgZone);

  constructor() {
    addIcons({chevronBack,imageOutline,cropOutline,closeCircleOutline,sendOutline});
  }

  goBack() {
    this.router.navigate(['/app/home']);
  }

  onFileInputClick() {
    document.getElementById('fileInput')?.click();
  }

  onFileSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    if (!this.ALLOWED_TYPES.includes(file.type)) {
      this.showToast('Format tidak didukung. Gunakan JPEG, PNG, atau WebP.');
      return;
    }

    const sizeMB = file.size / (1024 * 1024);
    if (sizeMB > this.MAX_FILE_SIZE_MB) {
      this.showToast(`Ukuran foto maksimal ${this.MAX_FILE_SIZE_MB}MB.`);
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      this.sourceImage = new Image();
      this.sourceImage.onload = () => {
        this.ngZone.run(() => {
          this.imageLoaded.set(true);
          setTimeout(() => this.initCanvas(), 80);
        });
      };
      this.sourceImage.src = e.target?.result as string;
    };
    reader.readAsDataURL(file);
    input.value = '';
  }

  clearImage() {
    this.imageLoaded.set(false);
    this.croppedDataUrl.set(null);
    this.croppedBlob.set(null);
    this.caption.set('');
  }

  private computeCoverFit(size: number) {
    const img = this.sourceImage;
    const imgAspect = img.naturalWidth / img.naturalHeight;

    if (imgAspect > 1) {
      this.drawH = size;
      this.drawW = size * imgAspect;
      this.drawX = -(this.drawW - size) / 2;
      this.drawY = 0;
    } else {
      this.drawW = size;
      this.drawH = size / imgAspect;
      this.drawX = 0;
      this.drawY = -(this.drawH - size) / 2;
    }
  }

  private initCanvas() {
    const container = this.cropContainerRef?.nativeElement;
    const canvas = this.cropCanvasRef?.nativeElement;
    if (!container || !canvas) return;

    this.canvasEl = canvas;
    this.ctx = canvas.getContext('2d')!;

    const containerWidth = container.clientWidth;
    this.canvasDisplaySize = containerWidth;

    canvas.width = containerWidth;
    canvas.height = containerWidth;
    canvas.style.width = `${containerWidth}px`;
    canvas.style.height = `${containerWidth}px`;

    this.computeCoverFit(containerWidth);

    // Initial crop: centered square at 85% of canvas
    this.cropSize = Math.floor(containerWidth * 0.85);
    this.cropX = Math.floor((containerWidth - this.cropSize) / 2);
    this.cropY = Math.floor((containerWidth - this.cropSize) / 2);

    this.attachCanvasListeners();
    this.drawCanvas();
  }

  private drawCanvas() {
    if (!this.ctx || !this.canvasEl) return;
    const size = this.canvasDisplaySize;
    const img = this.sourceImage;

    this.ctx.clearRect(0, 0, size, size);
    this.ctx.drawImage(img, this.drawX, this.drawY, this.drawW, this.drawH);

    // Dim overlay
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.55)';
    this.ctx.fillRect(0, 0, size, size);

    // Restore clear image inside crop box
    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(this.cropX, this.cropY, this.cropSize, this.cropSize);
    this.ctx.clip();
    this.ctx.drawImage(img, this.drawX, this.drawY, this.drawW, this.drawH);
    this.ctx.restore();

    // Crop border
    this.ctx.strokeStyle = '#ffffff';
    this.ctx.lineWidth = 2;
    this.ctx.strokeRect(this.cropX + 1, this.cropY + 1, this.cropSize - 2, this.cropSize - 2);

    // Corner handles
    const h = 18;
    const corners: [number, number][] = [
      [this.cropX, this.cropY],
      [this.cropX + this.cropSize, this.cropY],
      [this.cropX, this.cropY + this.cropSize],
      [this.cropX + this.cropSize, this.cropY + this.cropSize],
    ];
    this.ctx.fillStyle = '#ffffff';
    corners.forEach(([cx, cy]) => {
      const dx = cx === this.cropX ? 1 : -1;
      const dy = cy === this.cropY ? 1 : -1;
      this.ctx.fillRect(cx, cy, dx * h, 3);
      this.ctx.fillRect(cx, cy, 3, dy * h);
    });

    // Rule-of-thirds grid
    this.ctx.strokeStyle = 'rgba(255,255,255,0.25)';
    this.ctx.lineWidth = 0.5;
    const t = this.cropSize / 3;
    this.ctx.beginPath();
    for (let i = 1; i < 3; i++) {
      this.ctx.moveTo(this.cropX + t * i, this.cropY);
      this.ctx.lineTo(this.cropX + t * i, this.cropY + this.cropSize);
      this.ctx.moveTo(this.cropX, this.cropY + t * i);
      this.ctx.lineTo(this.cropX + this.cropSize, this.cropY + t * i);
    }
    this.ctx.stroke();
  }

  private attachCanvasListeners() {
    const canvas = this.canvasEl;

    const getPos = (e: MouseEvent | TouchEvent) => {
      const rect = canvas.getBoundingClientRect();
      const src = e instanceof MouseEvent ? e : e.touches[0];
      return { x: src.clientX - rect.left, y: src.clientY - rect.top };
    };

    const onStart = (e: MouseEvent | TouchEvent) => {
      const pos = getPos(e);
      if (
        pos.x >= this.cropX &&
        pos.x <= this.cropX + this.cropSize &&
        pos.y >= this.cropY &&
        pos.y <= this.cropY + this.cropSize
      ) {
        e.preventDefault();
        this.isDragging = true;
        this.dragStartX = pos.x;
        this.dragStartY = pos.y;
        this.dragStartCropX = this.cropX;
        this.dragStartCropY = this.cropY;
      }
    };

    const onMove = (e: MouseEvent | TouchEvent) => {
      if (!this.isDragging) return;
      e.preventDefault();
      const pos = getPos(e);
      const newX = Math.max(
        0,
        Math.min(
          this.dragStartCropX + (pos.x - this.dragStartX),
          this.canvasDisplaySize - this.cropSize
        )
      );
      const newY = Math.max(
        0,
        Math.min(
          this.dragStartCropY + (pos.y - this.dragStartY),
          this.canvasDisplaySize - this.cropSize
        )
      );
      this.cropX = newX;
      this.cropY = newY;
      this.drawCanvas();
    };

    const onEnd = () => {
      this.isDragging = false;
    };

    canvas.addEventListener('mousedown', onStart);
    canvas.addEventListener('mousemove', onMove);
    canvas.addEventListener('mouseup', onEnd);
    canvas.addEventListener('touchstart', onStart, { passive: false });
    canvas.addEventListener('touchmove', onMove, { passive: false });
    canvas.addEventListener('touchend', onEnd);
  }

  cropImage() {
    const img = this.sourceImage;

    // Map crop box display coords back to source image coords
    const srcX = (this.cropX - this.drawX) * (img.naturalWidth / this.drawW);
    const srcY = (this.cropY - this.drawY) * (img.naturalHeight / this.drawH);
    const srcSize = this.cropSize * (img.naturalWidth / this.drawW);

    const output = document.createElement('canvas');
    output.width = this.OUTPUT_SIZE;
    output.height = this.OUTPUT_SIZE;
    const outCtx = output.getContext('2d')!;
    outCtx.drawImage(
      img,
      srcX,
      srcY,
      srcSize,
      srcSize,
      0,
      0,
      this.OUTPUT_SIZE,
      this.OUTPUT_SIZE
    );

    output.toBlob(
      (blob) => {
        if (!blob) return;
        this.ngZone.run(() => {
          this.croppedBlob.set(blob);
          this.croppedDataUrl.set(output.toDataURL('image/webp', 0.9));

          // Scroll to top after crop
          setTimeout(() => {
            this.content?.scrollToTop();
          }, 100);
        });
      },
      'image/webp',
      0.9
    );
  }

  async onPost() {
    const blob = this.croppedBlob();
    const captionText = this.caption().trim();

    if (!blob) {
      this.showToast('Silakan crop foto terlebih dahulu.');
      return;
    }

    if (!captionText) {
      this.showToast('Silakan isi caption.');
      return;
    }

    const serverId = this.stateService.activeServerId();
    if (!serverId) {
      this.showToast('Pilih server terlebih dahulu dari homepage.');
      return;
    }

    this.isSubmitting.set(true);

    const formData = new FormData();
    formData.append('image', blob, 'post.webp');
    formData.append('caption', captionText);

    this.api
      .post<any>(`servers/${serverId}/posts`, formData)
      .subscribe({
        next: () => {
          this.isSubmitting.set(false);
          this.showToast('Post berhasil dibagikan!');
          this.router.navigateByUrl('/app/home', { replaceUrl: true });
        },
        error: (err: any) => {
          this.isSubmitting.set(false);
          const msg =
            err?.error?.error?.message ?? 'Gagal membuat post. Coba lagi.';
          this.showToast(msg);
        },
      });
  }

  private async showToast(message: string) {
    const toast = await this.toastCtrl.create({
      message,
      duration: 3000,
      position: 'bottom',
      cssClass: 'virdan-toast',
    });
    await toast.present();
  }
}
