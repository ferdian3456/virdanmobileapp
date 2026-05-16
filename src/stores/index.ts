import { store } from 'quasar/wrappers'
import { createPinia } from 'pinia'
import type { Router } from 'vue-router'

/*
 * When adding Pinia to your app, you should also add it to
 * your package.json dependencies and your quasar.config.ts.
 */

declare module 'pinia' {
  export interface PiniaCustomProperties {
    readonly router: Router;
  }
}

/*
 * If not building with SSR mode, you can directly export the Store instantiation;
 * the function below can be replaced by: export default createPinia()
 */

export default store((/* { ssrContext } */) => {
  const pinia = createPinia()

  // You can add Pinia plugins here
  // pinia.use(SomePiniaPlugin)

  return pinia
})
