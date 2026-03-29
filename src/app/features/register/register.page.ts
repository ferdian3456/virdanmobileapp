import { Component, CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { IonContent } from '@ionic/angular/standalone';
import { ApiService } from '../../core/services/api';
import { AuthService } from '../../core/services/auth';
import { arrowBackOutline } from 'ionicons/icons';
import { addIcons } from 'ionicons';
import { SignupStartResponse } from '../../core/models/auth.model';

@Component({
  selector: 'app-register',
  standalone: true,
  host: { class: 'ion-page' },
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  imports: [FormsModule, IonContent],
  templateUrl: './register.page.html',
  styleUrl: './register.page.scss'
})
export class RegisterPage {
  data: any = {
    email: '',
  };
  loading = false;
  errors: any = {};

  constructor(public router: Router, private api: ApiService, private auth: AuthService) {
    addIcons({ arrowBackOutline });
  }

  register() {
    (document.activeElement as HTMLElement)?.blur();
    this.errors = {}
    if (!this.data.email) {
      this.errors.email = 'Username is required to not be empty.';
      return;
    }
    this.loading = true;
    this.api.post<SignupStartResponse>('auth/signup/start', this.data, false).subscribe({
      next: async (res: SignupStartResponse) => {
        await this.auth.setSessionId(res.sessionId);
        await this.auth.setOtpExpiresAt(res.otpExpiresAt);
        this.router.navigate(['/verify-otp'], {
          state: { otpExpiresAt: res.otpExpiresAt }
        });
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