import type { PluginApi } from 'vue-loading-overlay'
import type { InjectionKey } from 'vue'

// loading provide
export const LoadingKey: InjectionKey<PluginApi> = Symbol('$loading')
