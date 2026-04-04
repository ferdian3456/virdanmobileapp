import { Component, OnInit, signal, inject } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  IonContent,
  IonButton,
  IonIcon,
} from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import {
  arrowBackOutline,
  chevronForwardOutline,
  personOutline,
  lockClosedOutline,
  notificationsOutline,
  colorPaletteOutline,
  globeOutline,
  helpCircleOutline,
  chatbubbleOutline,
  logOutOutline,
  layersOutline,
} from 'ionicons/icons';
import { Router } from '@angular/router';
import { ApiService } from '../../core/services/api';
import { AuthService } from '../../core/services/auth';
import { StateService } from '../../core/services/state.service';

interface UserProfile {
  id: string;
  username: string;
  fullname: string;
  email: string;
  avatarImage: string | null;
}

@Component({
  selector: 'app-settings',
  templateUrl: './settings.page.html',
  styleUrls: ['./settings.page.scss'],
  standalone: true,
  imports: [
    IonContent,
    IonButton,
    IonIcon,
    CommonModule,
    FormsModule,
  ],
})
export class SettingsPage implements OnInit {
  user = signal<UserProfile | null>(null);
  loadingProfile = signal(true);

  private api = inject(ApiService);
  private auth = inject(AuthService);
  private router = inject(Router);
  private location = inject(Location);
  private stateService = inject(StateService);

  constructor() {
    addIcons({
      arrowBackOutline,
      chevronForwardOutline,
      personOutline,
      lockClosedOutline,
      notificationsOutline,
      colorPaletteOutline,
      globeOutline,
      helpCircleOutline,
      chatbubbleOutline,
      logOutOutline,
      layersOutline,
    });
  }

  ngOnInit() {
    this.loadProfile();
  }

  loadProfile() {
    this.loadingProfile.set(true);
    this.api.get<UserProfile>('users/me').subscribe({
      next: (res) => {
        this.user.set(res);
        this.loadingProfile.set(false);
      },
      error: () => {
        this.loadingProfile.set(false);
      },
    });
  }

  goBack() {
    this.location.back();
  }

  async logout() {
    await this.auth.logout();
    this.router.navigate(['/login'], { replaceUrl: true });
  }

  getUserInitial(): string {
    const u = this.user();
    if (!u) return '';
    return (
      u.fullname?.[0]?.toUpperCase() ?? u.username?.[0]?.toUpperCase() ?? ''
    );
  }
}
