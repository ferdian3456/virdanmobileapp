import { Injectable, signal, computed } from "@angular/core";

@Injectable({ providedIn: "root" })
export class StateService {
  // Active server untuk create post dan fitur lain yang butuh serverId
  private _activeServerId = signal<string | null>(null);
  activeServerId = computed(() => this._activeServerId());

  /**
   * Set active server (dipanggil di homepage dengan server pertama)
   */
  setActiveServer(serverId: string) {
    this._activeServerId.set(serverId);
  }

  /**
   * Update active server (dipanggil saat user pilih server lain)
   */
  updateActiveServer(serverId: string) {
    this._activeServerId.set(serverId);
  }
}
