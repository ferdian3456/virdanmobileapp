import { Component, CUSTOM_ELEMENTS_SCHEMA, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { IonContent, IonIcon } from '@ionic/angular/standalone';
import { ApiService } from '../../core/services/api';
import { AuthService } from '../../core/services/auth';
import { arrowBackOutline } from 'ionicons/icons';
import { addIcons } from 'ionicons';
import { Router } from '@angular/router';
import { ApiSuccessResponseNoData } from '../../core/models/api.model';


@Component({
  selector: 'app-verify-otp',
  templateUrl: './verify-otp.page.html',
  styleUrls: ['./verify-otp.page.scss'],
  host: { class: 'ion-page' },
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  standalone: true,
  imports: [IonIcon, IonContent, CommonModule, FormsModule]
})
export class VerifyOtpPage implements OnInit, OnDestroy {
  data: any = {
    sessionId: '',
    otp: '',
  };
  loading = false;
  errors: any = {};
  otpDigits: string[] = ['', '', '', '', '', ''];
  sessionId: string = '';
  otpExpiresAt: number = 0;
  timeLeft: string = '';
  private timerInterval: any;

  constructor(public router: Router, private api: ApiService, private auth: AuthService) {
    addIcons({ arrowBackOutline });
    const nav = this.router.getCurrentNavigation();
    this.otpExpiresAt = nav?.extras?.state?.['otpExpiresAt'] ?? 0;
  }

  async ngOnInit() {
    this.data.sessionId = await this.auth.getSessionId() ?? '';
    console.log("expires at in verify-otp: ", this.otpExpiresAt);
    this.startTimer();
  }

  startTimer() {
    this.timerInterval = setInterval(() => {
      const now = Math.floor(Date.now() / 1000);
      const diff = this.otpExpiresAt - now;
      if (diff <= 0) {
        this.timeLeft = 'Expired';
        clearInterval(this.timerInterval);
      } else {
        const m = Math.floor(diff / 60);
        const s = diff % 60;
        this.timeLeft = `${m}:${s.toString().padStart(2, '0')}`;
      }
    }, 1000);
  }

  ngOnDestroy() {
    clearInterval(this.timerInterval);
  }

  verifyOtp() {
    this.errors = {};
    if (this.otpValue.length < 6) {
      this.errors['otp'] = 'Please enter the complete 6-digit code.';
      return;
    }
    this.loading = true;
    this.data.otp = this.otpValue
    this.api.post<ApiSuccessResponseNoData>('auth/signup/otp', this.data, false).subscribe({
      next: (res) => {
        this.loading = false;
        this.router.navigate(['/verify-username']);
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

  onOtpInput(event: any, index: number) {
    const val = event.target.value;
    this.otpDigits[index] = val;
    if (val && index < 5) {
      document.getElementById(`otp-${index + 1}`)?.focus();
    }
  }

  onOtpKeydown(event: KeyboardEvent, index: number) {
    if (event.key === 'Backspace' && !this.otpDigits[index] && index > 0) {
      document.getElementById(`otp-${index - 1}`)?.focus();
    }
  }

  get otpValue() {
    return this.otpDigits.join('');
  }
}
