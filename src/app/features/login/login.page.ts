import { Component, CUSTOM_ELEMENTS_SCHEMA, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { IonContent } from '@ionic/angular/standalone';
import { ApiService } from '../../core/services/api';
import { AuthService } from '../../core/services/auth';
import { IonIcon } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { eyeOutline, eyeOffOutline } from 'ionicons/icons';
import { LoginResponse } from '../../core/models/auth.model';
import { AlertController } from '@ionic/angular/standalone';


@Component({
  selector: 'app-login',
  standalone: true,
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  host: { class: 'ion-page' },
  imports: [FormsModule, IonContent, IonIcon],
  templateUrl: './login.page.html',
  styleUrl: './login.page.scss'
})

export class LoginPage implements OnInit {
  data: any = { username: '', password: '' };
  loading = false;
  errorMsg = '';
  errors: any = {};
  showPassword = false;
  showResumeModal = false;
  pendingStep = '';

  constructor(public router: Router, private api: ApiService, private auth: AuthService, private alertCtrl: AlertController) {
    addIcons({ eyeOutline, eyeOffOutline })
  }

  async ngOnInit() {
    const sessionId = await this.auth.getSessionId();
    if (!sessionId) return;

    this.api.get(`auth/signup/${sessionId}/status`, true).subscribe({
      next: async (res: any) => {
        if (res.step === 'password_set') {
          await this.auth.clearSessionId();
          return;
        }
        this.pendingStep = res.step;
        this.showResumeModal = true;
      },
      error: async () => {
        await this.auth.clearSessionId();
      }
    });
  }

  async continueRegistration() {
    this.showResumeModal = false;
    (document.activeElement as HTMLElement)?.blur();
    switch (this.pendingStep) {
      case 'start_signup': this.router.navigate(['/verify-otp']); break;
      case 'otp_verified': this.router.navigate(['/verify-username']); break;
      case 'username_set': this.router.navigate(['/verify-password']); break;
    }
  }

  async startOver() {
    await this.auth.clearSessionId();
    this.showResumeModal = false;
    (document.activeElement as HTMLElement)?.blur();
  }

  login() {
    this.errors = {}
    if (!this.data.username) {
      this.errors.username = 'Username is required to not be empty.';
      return;
    }
    if (!this.data.password) {
      this.errors.password = 'Password is required to not be empty.';
      return;
    }
    this.loading = true;
    this.api.post<LoginResponse>('auth/login', this.data, false).subscribe({
      next: async (res) => {
        await this.auth.setTokens(res);
        this.loading = false;
        this.router.navigate(['/app/home']);
      },
      error: (err) => {
        if (err.param) {
          this.errors[err.param] = err.message;
        } else {
          this.errors['general'] = err.message;
        }
        this.loading = false;
      }
    });
  }
}