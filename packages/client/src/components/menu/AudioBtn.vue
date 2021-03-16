<template>
  <agm-button icon @click="handleAudio" :color="color">
    <agm-icon :icon="icon"></agm-icon>
  </agm-button>
</template>

<script lang="ts">
import { defineComponent } from "vue";

export default defineComponent({
  data() {
    return {
      icon: "mdi:microphone",
      color: "black",
      recognition: null,
      keywords: ["fullscreen"],
      content: "",
    };
  },
  mounted() {
    this.init();
  },
  methods: {
    init() {
      // eslint-disable
      var SpeechRecognition = SpeechRecognition || webkitSpeechRecognition;
      var SpeechGrammarList = SpeechGrammarList || webkitSpeechGrammarList;
      var SpeechRecognitionEvent =
        SpeechRecognitionEvent || webkitSpeechRecognitionEvent;

      const grammar =
        "#JSGF V1.0; grammar colors; public <color> = " +
        this.keywords.join(" | ") +
        " ;";

      const recognition = new SpeechRecognition();
      this.recognition = recognition;

      const speechRecognitionList = new SpeechGrammarList();
      speechRecognitionList.addFromString(grammar, 1);
      recognition.grammars = speechRecognitionList;
      recognition.continuous = false;
      recognition.lang = "en-US";
      recognition.interimResults = false;
      recognition.maxAlternatives = 1;
      recognition.onresult = (event) => {
        // The SpeechRecognitionEvent results property returns a SpeechRecognitionResultList object
        // The SpeechRecognitionResultList object contains SpeechRecognitionResult objects.
        // It has a getter so it can be accessed like an array
        // The first [0] returns the SpeechRecognitionResult at the last position.
        // Each SpeechRecognitionResult object contains SpeechRecognitionAlternative objects that contain individual results.
        // These also have getters so they can be accessed like arrays.
        // The second [0] returns the SpeechRecognitionAlternative at position 0.
        // We then return the transcript property of the SpeechRecognitionAlternative object
        const content = event.results[0][0].transcript;
        this.content = content;

        this.$notify({
          title: content,
          icon: "mdi:microphone",
          color: "var(--agm-success)",
          message: "Confidence: " + event.results[0][0].confidence.toFixed(2),
        });
      };

      recognition.onspeechend = () => {
        this.icon = "mdi:microphone";
        this.color = "black";
        recognition.stop();
      };

      recognition.onnomatch = (event) => {
        this.$notify({
          title: this.content,
          icon: "mdi:alert",
          color: "var(--agm-warning)",
          message: "I didn't recognise that command.",
        });
      };

      recognition.onerror = function (event) {
        this.$notify({
          title: this.content,
          icon: "mdi:alert",
          color: "var(--agm-error)",
          message: "Error occurred in recognition: " + event.error,
        });
      };
    },
    handleAudio() {
      this.icon = "mdi:microphone-settings";
      this.color = "var(--agm-success)";
      this.recognition.start();
    },
  },
});
</script>
