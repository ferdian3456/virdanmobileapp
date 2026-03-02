import { Component, CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { IonContent } from '@ionic/angular/standalone';
import { ApiService } from '../../core/services/api';
import { AuthService } from '../../core/services/auth';
import { IonIcon } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { eyeOutline, eyeOffOutline } from 'ionicons/icons';
import { LoginResponse } from '../../core/models/auth.model';


@Component({
  selector: 'app-login',
  standalone: true,
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  host: { class: 'ion-page' },
  imports: [FormsModule, IonContent],
  templateUrl: './login.page.html',
  styleUrl: './login.page.scss'
})

export class LoginPage {
  data: any = { username: '', password: '' };
  loading = false;
  errorMsg = '';
  errors: any = {};
  showPassword = false;

  constructor(public router: Router, private api: ApiService, private auth: AuthService) {
    addIcons({ eyeOutline, eyeOffOutline })
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
    this.api.post<LoginResponse>('auth/login', this.data, true).subscribe({
      next: (res) => {
        // res.sessionId, res.otp sudah typed
        // this.router.navigate(['/register/verify'], {
        //   state: { sessionId: res.sessionId }
        // });
        console.log("full response:", res)
        this.loading = false;
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