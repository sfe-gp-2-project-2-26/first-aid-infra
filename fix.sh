cd /home/ubuntu/medaid/app

cat > .env <<ENV
GEMINI_API_KEY=$(grep GEMINI_API_KEY terraform.tfvars | cut -d'"' -f2)
GROQ_API_KEY=$(grep GROQ_API_KEY terraform.tfvars | cut -d'"' -f2)
JWT_SECRET_KEY=medaid-production-super-secret-key
ENV

cat > docker-compose.prod.yml <<'COMPOSE'
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    command: sh -c "npm run build && npm run preview -- --host 0.0.0.0 --port 8080"
    networks:
      - medaid-net
    environment:
      - AUTH_BACKEND_URL=http://auth-service:4000
      - MAP_BACKEND_URL=http://map-service:5000
      - BACKEND_URL=http://ai-service:3000
      - VITE_AMBULANCE_NUMBER=+201154768115

  auth-service:
    build:
      context: ./auth-service
      dockerfile: Dockerfile
    command: npm start
    depends_on:
      - mongodb
    networks:
      - medaid-net
    environment:
      - PORT=4000
      - MONGODB_URI=mongodb://mongodb:27017/firstaid
      - JWT_SECRET_KEY=${JWT_SECRET_KEY}
      - PYTHON_BACKEND_URL=http://ai-service:3000
      - FRONTEND_URL=https://medaid.abdallahgabr.me

  ai-service:
    build:
      context: ./ai-service
      dockerfile: Dockerfile
    depends_on:
      - qdrant
      - bge-service
    networks:
      - medaid-net
    environment:
      - QDRANT_URL=http://qdrant:6333
      - EMBEDDING_URL=http://bge-service:8000
      - GEMINI_API_KEY=${GEMINI_API_KEY}
      - GROQ_API_KEY=${GROQ_API_KEY}

  map-service:
    build:
      context: ./map-service
      dockerfile: Dockerfile
    networks:
      - medaid-net

  bge-service:
    build:
      context: ./bge-service
      dockerfile: Dockerfile
    volumes:
      - hf-cache:/root/.cache/huggingface
    networks:
      - medaid-net
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  mongodb:
    image: mongo:6
    volumes:
      - mongo-data:/data/db
    networks:
      - medaid-net

  qdrant:
    image: qdrant/qdrant
    volumes:
      - qdrant-data:/qdrant/storage
    networks:
      - medaid-net

  caddy:
    image: caddy:2-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - medaid-net
    depends_on:
      - frontend

networks:
  medaid-net:
    driver: bridge

volumes:
  mongo-data:
  qdrant-data:
  hf-cache:
  caddy_data:
  caddy_config:
COMPOSE
cat > Caddyfile <<'CADDY'
medaid.abdallahgabr.me {
    reverse_proxy frontend:8080
}
CADDY
sudo docker compose -f docker-compose.prod.yml up -d --build
