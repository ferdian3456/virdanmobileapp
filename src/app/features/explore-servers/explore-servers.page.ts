import { Component, CUSTOM_ELEMENTS_SCHEMA, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { IonContent, IonIcon, IonInfiniteScroll, IonInfiniteScrollContent } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { arrowBackOutline, searchOutline, peopleOutline } from 'ionicons/icons';
import { ApiService } from '../../core/services/api';

interface Category {
  id: number;
  categoryName: string;
}

interface Server {
  id: string;
  name: string;
  shortName: string;
  categoryName: string;
  description: string;
  avatarImageUrl: string;
  bannerImageUrl: string;
}

interface CategoryListResponse {
  data: Category[];
  page: { nextCursor: string };
}

interface ServerListResponse {
  data: Server[];
  page: { nextCursor: string };
}

@Component({
  selector: 'app-explore-servers',
  templateUrl: './explore-servers.page.html',
  styleUrls: ['./explore-servers.page.scss'],
  standalone: true,
  host: { class: 'ion-page' },
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  imports: [IonContent, IonIcon, CommonModule, FormsModule, IonInfiniteScroll, IonInfiniteScrollContent]
})
export class ExploreServersPage implements OnInit {
  categories = signal<Category[]>([]);
  servers = signal<Server[]>([]);
  activeCategoryId = signal<number>(0);
  searchQuery = '';
  nextCursor = '';
  hasMore = true;
  loading = true;
  joiningServerId = signal<string>('');

  constructor(public router: Router, private api: ApiService) {
    addIcons({ arrowBackOutline, searchOutline, peopleOutline });
  }

  ngOnInit() {
    this.loadCategories();
    this.loadServers();
  }

  loadCategories() {
    this.api.get<CategoryListResponse>('servers/categories').subscribe({
      next: (res) => this.categories.set(res.data),
      error: () => {}
    });
  }

  loadServers(cursor: string = '') {
    this.loading = true;
    let url = 'servers/';
    const params: string[] = [];
    if (this.activeCategoryId() > 0) params.push(`categoryId=${this.activeCategoryId()}`);
    if (cursor) params.push(`cursor=${cursor}`);
    if (params.length) url += '?' + params.join('&');

    this.api.get<ServerListResponse>(url).subscribe({
      next: (res) => {
        if (cursor) {
          this.servers.update(current => [...current, ...res.data]);
        } else {
          this.servers.set(res.data);
        }
        this.nextCursor = res.page.nextCursor;
        this.hasMore = !!res.page.nextCursor;
        this.loading = false;
      },
      error: () => { this.loading = false; }
    });
  }

  selectCategory(categoryId: number) {
    if (this.activeCategoryId() === categoryId) return;
    this.activeCategoryId.set(categoryId);
    this.nextCursor = '';
    this.hasMore = true;
    this.loadServers();
  }

  loadMore(event: any) {
    if (!this.hasMore) { event.target.complete(); return; }
    this.loadServers(this.nextCursor);
    setTimeout(() => event.target.complete(), 1000);
  }

  joinServer(serverId: string) {
    this.joiningServerId.set(serverId);
    this.api.post(`servers/${serverId}/join`, {}).subscribe({
      next: () => {
        this.joiningServerId.set('');
        this.router.navigate(['/app/home']);
      },
      error: () => {
        this.joiningServerId.set('');
      }
    });
  }

  get filteredServers() {
    if (!this.searchQuery.trim()) return this.servers();
    return this.servers().filter(s =>
      s.name.toLowerCase().includes(this.searchQuery.toLowerCase()) ||
      s.description?.toLowerCase().includes(this.searchQuery.toLowerCase())
    );
  }
}