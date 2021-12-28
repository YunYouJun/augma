<template>
  <agm-button icon @click="handleAudio">
    <agm-icon :color="color">
      <i-mdi-microphone v-if="!status" color="var(--agm-color-success)" />
      <i-mdi-microphone-settings v-else-if="status === 'settings'" />
      <i-mdi-alert v-else-if="status==='alert'" color="var(--agm-error)" />
    </agm-icon>
  </agm-button>
</template>

<script lang="ts" setup>
/* eslint-disable eslint-comments/no-unlimited-disable */
/* eslint-disable */

const recognitionRef  = ref()
const color = ref('success')
const keywords = ref('fullscreen')
const content = ref('')
const icon = ref('')
const status = ref('')

const init = () => {
  var SpeechRecognition = SpeechRecognition || webkitSpeechRecognition
  var SpeechGrammarList = SpeechGrammarList || webkitSpeechGrammarList
  var SpeechRecognitionEvent
    = SpeechRecognitionEvent || webkitSpeechRecognitionEvent

  const grammar
    = `#JSGF V1.0; grammar colors; public <color> = ${
      keywords.value.join(' | ')
    } ;`

  const recognition = new SpeechRecognition()
  recognitionRef.value = recognition

  const speechRecognitionList = new SpeechGrammarList()
  speechRecognitionList.addFromString(grammar, 1)
  recognition.grammars = speechRecognitionList
  recognition.continuous = false
  recognition.lang = 'en-US'
  recognition.interimResults = false
  recognition.maxAlternatives = 1
  recognition.onresult = (event) => {
    // The SpeechRecognitionEvent results property returns a SpeechRecognitionResultList object
    // The SpeechRecognitionResultList object contains SpeechRecognitionResult objects.
    // It has a getter so it can be accessed like an array
    // The first [0] returns the SpeechRecognitionResult at the last position.
    // Each SpeechRecognitionResult object contains SpeechRecognitionAlternative objects that contain individual results.
    // These also have getters so they can be accessed like arrays.
    // The second [0] returns the SpeechRecognitionAlternative at position 0.
    // We then return the transcript property of the SpeechRecognitionAlternative object
    content.value = event.results[0][0].transcript

    this.$notify({
      title: content.value,
      icon: 'mdi:microphone',
      color: 'var(--agm-color-success)',
      message: `Confidence: ${event.results[0][0].confidence.toFixed(2)}`,
    })
  }

  recognition.onspeechend = () => {
    this.icon = 'mdi:microphone'
    this.color = 'black'
    recognition.stop()
  }

  recognition.onnomatch = (event) => {
    this.$notify({
      title: content.value,
      icon: 'mdi:alert',
      color: 'var(--agm-color-warning)',
      message: 'I didn\'t recognise that command.',
    })
  }

  recognition.onerror = function(event) {
    this.$notify({
      title: content.value,
      icon: 'mdi:alert',
      color: 'var(--agm-error)',
      message: `Error occurred in recognition: ${event.error}`,
    })
  }
}

onMounted(() => {
  init()
})

const handleAudio = () => {
  icon.value = 'mdi:microphone-settings'
  recognitionRef.value.start()
}
</script>
