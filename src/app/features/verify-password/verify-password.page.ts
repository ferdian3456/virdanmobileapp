import { Component, CUSTOM_ELEMENTS_SCHEMA, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { IonContent, IonIcon } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { arrowBackOutline, eyeOutline, eyeOffOutline } from 'ionicons/icons';
import { ApiService } from '../../core/services/api';
import { AuthService } from '../../core/services/auth';
import { LoginResponse } from '../../core/models/auth.model';

@Component({
  selector: 'app-verify-password',
  templateUrl: './verify-password.page.html',
  styleUrls: ['./verify-password.page.scss'],
  host: { class: 'ion-page' },
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  standalone: true,
  imports: [IonIcon, IonContent, FormsModule]
})
export class VerifyPasswordPage implements OnInit {
  data: any = { sessionId: '', password: '' };
  confirmPassword = '';
  showPassword = false;
  showConfirmPassword = false;
  loading = false;
  errors: any = {};

  constructor(public router: Router, private api: ApiService, private auth: AuthService) {
    addIcons({ arrowBackOutline, eyeOutline, eyeOffOutline });
  }

  async ngOnInit() {
    this.data.sessionId = await this.auth.getSessionId() ?? '';
  }

  submit() {
    this.errors = {};
    if (!this.data.password) {
      this.errors['password'] = 'Password is required.';
      return;
    }
    if (this.data.password.length < 8) {
      this.errors['password'] = 'Password must be at least 8 characters.';
      return;
    }
    if (this.data.password !== this.confirmPassword) {
      this.errors['confirmPassword'] = 'Passwords do not match.';
      return;
    }
    this.loading = true;
    this.api.post<LoginResponse>('auth/signup/password', this.data, true).subscribe({
      next: async (res) => {
        await this.auth.setTokens(res);
        await this.auth.clearSessionId();
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