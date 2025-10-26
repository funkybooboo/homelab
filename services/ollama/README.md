# Ollama Docker Setup

Local LLM inference server for running large language models.

## Prerequisites

- Docker and Docker Compose installed
- Port 11434 available on your host
- Sufficient disk space for models (models can be several GB each)
- Optional: NVIDIA GPU for faster inference

## Quick Start

### 1. Start the Service

```bash
docker compose up -d
```

### 2. Pull a Model

```bash
# Pull a model (e.g., llama2, mistral, codellama)
docker compose exec ollama ollama pull llama2

# Other popular models
docker compose exec ollama ollama pull mistral
docker compose exec ollama ollama pull codellama
docker compose exec ollama ollama pull llama2:13b
```

### 3. Test the Model

```bash
# Run interactive chat
docker compose exec -it ollama ollama run llama2

# Or use the API
curl http://localhost:11434/api/generate -d '{
  "model": "llama2",
  "prompt": "Why is the sky blue?"
}'
```

## Common Commands

### View Logs
```bash
docker compose logs -f
```

### List Downloaded Models
```bash
docker compose exec ollama ollama list
```

### Pull a Model
```bash
docker compose exec ollama ollama pull <model-name>
```

### Remove a Model
```bash
docker compose exec ollama ollama rm <model-name>
```

### Run Interactive Chat
```bash
docker compose exec -it ollama ollama run <model-name>
```

### Stop Service
```bash
docker compose down
```

### Stop and Remove Volumes (⚠️ This deletes all models!)
```bash
docker compose down -v
```

### Update Ollama
```bash
docker compose pull
docker compose up -d
```

## API Usage

### Generate Text
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama2",
  "prompt": "Tell me a joke",
  "stream": false
}'
```

### Chat API
```bash
curl http://localhost:11434/api/chat -d '{
  "model": "llama2",
  "messages": [
    {
      "role": "user",
      "content": "Why is the ocean salty?"
    }
  ],
  "stream": false
}'
```

### List Models API
```bash
curl http://localhost:11434/api/tags
```

## GPU Support (NVIDIA)

To enable GPU support:

1. Install NVIDIA Container Toolkit
2. Uncomment the `deploy` section in `docker-compose.yml`
3. Restart the service: `docker compose up -d`

## Popular Models

- **llama2** - Meta's Llama 2 (7B, 13B, 70B variants)
- **mistral** - Mistral 7B model
- **codellama** - Code-specialized Llama model
- **phi** - Microsoft's small but capable model
- **neural-chat** - Intel's conversational model
- **llama2-uncensored** - Uncensored variant of Llama 2

## Model Storage

Models are stored in the `ollama_data` volume. To see disk usage:

```bash
docker system df -v | grep ollama
```

## Integration with n8n

You can use Ollama with n8n for AI workflows:

1. Use the HTTP Request node in n8n
2. Point to `http://ollama:11434/api/generate`
3. Configure the request body with your prompt

## Troubleshooting

### Out of Memory
- Try smaller models (7B variants)
- Ensure sufficient RAM is available
- Check Docker resource limits

### Slow Generation
- Enable GPU support if available
- Use smaller models
- Check system resources

### Port Already in Use
- Change port mapping in docker-compose.yml
- Example: `"11435:11434"` instead of `"11434:11434"`

## Volumes

This setup creates one persistent volume:
- `ollama_data`: Model files and configuration

To inspect volume:
```bash
docker volume ls
docker volume inspect ollama_ollama_data
```

## More Information

- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/docs/README.md)
- [Ollama Model Library](https://ollama.ai/library)
- [Ollama API Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)
