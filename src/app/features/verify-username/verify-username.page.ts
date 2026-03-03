import { Component, CUSTOM_ELEMENTS_SCHEMA, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { IonContent, IonIcon } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { arrowBackOutline } from 'ionicons/icons';
import { ApiService } from '../../core/services/api';
import { AuthService } from '../../core/services/auth';
import { ApiSuccessResponseNoData } from '../../core/models/api.model';

@Component({
  selector: 'app-verify-username',
  templateUrl: './verify-username.page.html',
  styleUrls: ['./verify-username.page.scss'],
  host: { class: 'ion-page' },
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  standalone: true,
  imports: [IonIcon, IonContent, FormsModule]
})
export class VerifyUsernamePage implements OnInit {
  data: any = { sessionId: '', username: '' };
  loading = false;
  errors: any = {};

  constructor(public router: Router, private api: ApiService, private auth: AuthService) {
    addIcons({ arrowBackOutline });
  }

  async ngOnInit() {
    this.data.sessionId = await this.auth.getSessionId() ?? '';
  }

  submit() {
    this.errors = {};
    if (!this.data.username) {
      this.errors['username'] = 'Username is required.';
      return;
    }
    this.loading = true;
    this.api.post<ApiSuccessResponseNoData>('auth/signup/username', this.data, true).subscribe({
      next: async () => {
        this.router.navigate(['/verify-password']);
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