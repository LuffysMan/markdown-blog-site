const { createApp, ref, computed, onMounted } = Vue;

const app = createApp({
    setup() {
        const filename = ref('example.md');
        const content = ref('');
        const loading = ref(false);
        const saving = ref(false);
        const lastSaved = ref(null);
        const error = ref('');
        const successMessage = ref('');

        const renderedContent = computed(() => {
            return marked.parse(content.value || '## Preview\n*Your content will appear here*');
        });

        const showSuccess = (message) => {
            successMessage.value = message;
            setTimeout(() => {
                successMessage.value = '';
            }, 3000);
        };

        const showError = (message) => {
            error.value = message;
            setTimeout(() => {
                error.value = '';
            }, 5000);
        };

        const loadFile = async () => {
            if (!filename.value) {
                showError('Please enter a filename');
                return;
            }

            try {
                loading.value = true;
                error.value = '';

                const response = await fetch(`/blog/${encodeURIComponent(filename.value)}`);

                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error(`Failed to load: ${response.status} - ${errorText}`);
                }

                content.value = await response.text();
                lastSaved.value = null;
                showSuccess('File loaded successfully');

            } catch (err) {
                showError(err.message);
                console.error('Load error:', err);
            } finally {
                loading.value = false;
            }
        };

        const saveFile = async () => {
            if (!filename.value) {
                showError('Please enter a filename');
                return;
            }

            try {
                saving.value = true;
                error.value = '';

                const response = await fetch(`/blog/${encodeURIComponent(filename.value)}`, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'text/plain'
                    },
                    body: content.value
                });

                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error(`Failed to save: ${response.status} - ${errorText}`);
                }

                lastSaved.value = new Date();
                showSuccess('File saved successfully');

            } catch (err) {
                showError(err.message);
                console.error('Save error:', err);
            } finally {
                saving.value = false;
            }
        };

        const formatTime = (date) => {
            return new Date(date).toLocaleTimeString();
        };

        // Auto-load example file on page load
        onMounted(() => {
            // Optional: load a default file on startup
            // loadFile();
        });

        return {
            filename,
            content,
            loading,
            saving,
            lastSaved,
            error,
            successMessage,
            renderedContent,
            loadFile,
            saveFile,
            formatTime
        };
    }
});

app.mount('#app');