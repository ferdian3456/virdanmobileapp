import { Component, ElementRef, ViewChild, inject, signal, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import {
  IonHeader, IonToolbar, IonTitle, IonButtons, IonButton,
  IonContent, IonFooter, IonIcon, ToastController
} from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import {
  arrowBackOutline, imageOutline, pencilOutline, serverOutline,
  globeOutline, lockClosedOutline, reloadOutline, chevronDownOutline, checkmarkOutline
} from 'ionicons/icons';
import { Location } from '@angular/common';
import { firstValueFrom } from 'rxjs';
import { ApiService } from '../../core/services/api';

interface ServerCategory {
  id: number;
  categoryName: string;
}

interface CreateServerForm {
  name: string;
  shortName: string;
  category: number;
  description: string;
  isPrivate: boolean;
}

@Component({
  selector: 'app-create-server',
  templateUrl: './create-server.page.html',
  styleUrl: './create-server.page.scss',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    IonHeader, IonToolbar, IonTitle, IonButtons, IonButton,
    IonContent, IonFooter, IonIcon,
  ],
})
export class CreateServerPage {
  @ViewChild('avatarInput') avatarInput!: ElementRef<HTMLInputElement>;

  private apiService = inject(ApiService);
  private router = inject(Router);

  avatarPreview: string | null = null;
  avatarFile: File | null = null;
  isSubmitting = false;

  readonly ALLOWED_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
  readonly MAX_FILE_SIZE_MB = 5;

  categories = signal<ServerCategory[]>([]);
  isLoadingCategories = signal(false);
  isCategoryDropdownOpen = signal(false);

  form: CreateServerForm = {
    name: '',
    shortName: '',
    category: 0,
    description: '',
    isPrivate: false,
  };

  constructor(
    private location: Location,
    private toastCtrl: ToastController,
  ) {
    addIcons({
      arrowBackOutline, imageOutline, pencilOutline, serverOutline,
      globeOutline, lockClosedOutline, reloadOutline, chevronDownOutline, checkmarkOutline,
    });
    this.loadCategories();
  }

  private async loadCategories(): Promise<void> {
    this.isLoadingCategories.set(true);
    try {
      const response = await firstValueFrom(
        this.apiService.get<{ data: ServerCategory[] }>('servers/categories')
      );
      this.categories.set(response.data || []);
    } catch (err) {
      await this.showToast('Failed to load categories', 'danger');
    } finally {
      this.isLoadingCategories.set(false);
    }
  }

  selectCategory(categoryId: number): void {
    this.form.category = categoryId;
    this.isCategoryDropdownOpen.set(false);
  }

  getCategoryDisplayName(): string {
    if (!this.form.category || this.form.category === 0) {
      return 'Select category...';
    }
    const selected = this.categories().find(c => c.id === this.form.category);
    return selected?.categoryName || 'Select category...';
  }

  // Close dropdown when clicking outside
  @HostListener('document:click', ['$event'])
  onClickOutside(event: Event): void {
    const target = event.target as HTMLElement;
    const dropdownContainer = target.closest('.relative');
    if (!dropdownContainer && this.isCategoryDropdownOpen()) {
      this.isCategoryDropdownOpen.set(false);
    }
  }

  goBack(): void {
    this.location.back();
  }

  pickAvatar(): void {
    this.avatarInput.nativeElement.click();
  }

  onAvatarSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    if (!this.ALLOWED_TYPES.includes(file.type)) {
      this.showToast('Unsupported format. Use JPEG, PNG, or WebP.', 'danger');
      return;
    }

    const sizeMB = file.size / (1024 * 1024);
    if (sizeMB > this.MAX_FILE_SIZE_MB) {
      this.showToast(`Max icon size is ${this.MAX_FILE_SIZE_MB}MB.`, 'danger');
      return;
    }

    this.avatarFile = file;

    const reader = new FileReader();
    reader.onload = (e) => {
      this.avatarPreview = e.target?.result as string;
    };
    reader.readAsDataURL(file);
  }

  async submit(): Promise<void> {
    if (!this.form.name.trim() || !this.form.shortName.trim() || !this.form.category || this.form.category === 0 || this.isSubmitting) {
      if (!this.form.category || this.form.category === 0) {
        await this.showToast('Please select a category', 'danger');
      } else if (!this.form.shortName.trim()) {
        await this.showToast('Short name is required', 'danger');
      }
      return;
    }

    this.isSubmitting = true;

    const formData = new FormData();
    formData.append('name', this.form.name.trim());
    formData.append('shortName', this.form.shortName.trim());
    formData.append('categoryId', this.form.category.toString());
    formData.append('description', this.form.description.trim());
    formData.append('isPrivate', this.form.isPrivate.toString());

    if (this.avatarFile) {
      formData.append('avatar', this.avatarFile, this.avatarFile.name);
    }

    try {
      const response = await firstValueFrom(
        this.apiService.post<any>('servers/create', formData)
      );

      await this.showToast('Server created successfully!', 'success');
      this.router.navigate(['/app/home']);
    } catch (err: any) {
      const msg = err?.message ?? 'Failed to create server, please try again.';
      await this.showToast(msg, 'danger');
    } finally {
      this.isSubmitting = false;
    }
  }

  private async showToast(message: string, color: string): Promise<void> {
    const toast = await this.toastCtrl.create({
      message,
      duration: 2500,
      color,
      position: 'top',
    });
    await toast.present();
  }
}