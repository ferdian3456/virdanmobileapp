import { Component, CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';
import { RouterModule, RouterLink, RouterLinkActive, Router } from '@angular/router';
import { IonIcon } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { homeOutline, home, searchOutline, search, addCircleOutline, addCircle, notificationsOutline, notifications, personOutline, person } from 'ionicons/icons';

@Component({
  selector: 'app-main-layout',
  templateUrl: './main-layout.component.html',
  styleUrls: ['./main-layout.component.scss'],
  standalone: true,
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  imports: [RouterModule, IonIcon, RouterLink]
})
export class MainLayoutComponent {
  constructor(public router: Router) {
    addIcons({ homeOutline, home, searchOutline, search, addCircleOutline, addCircle, notificationsOutline, notifications, personOutline, person });
  }

  isActive(path: string): boolean {
    return this.router.url === path;
  }
}