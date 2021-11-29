import { useToast } from 'vue-toastification'

export const useAgmToast: () => ReturnType<typeof useToast> = () => {
  const toast = useToast()
  return toast
}
