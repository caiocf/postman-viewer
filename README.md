# Postman GUI via Docker com Persistência

Este projeto entrega o **Postman GUI** rodando dentro de um container Debian minimalista, acessível via navegador usando **noVNC**.  
A imagem instala a versão **9.31.30** — a última versão que ainda permite o uso **sem login obrigatório**.  
As coleções e ambientes são preservados mapeando o diretório `Partitions` do Postman do host para o container.

> ⚠️ **Importante:** a versão 9.31.30 **não abre partições criadas em versões mais novas** (Postman 10+).  
> Exporte suas coleções como JSON em uma versão compatível antes de migrar e **faça backup da pasta `Partitions`**.

---

## 🧩 Requisitos

- Docker 20.10+ e plugin Docker Compose
- Diretório `Partitions` do Postman existente:
  - **Windows:** `%APPDATA%\Postman\Partitions`
  - **macOS:** `~/Library/Application Support/Postman/Partitions`
  - **Linux:** `~/.config/Postman/Partitions`
- **Apple Silicon (M1/M2):** Docker Desktop com suporte à emulação `linux/amd64` habilitado (já configurado no Compose).

---

## 📁 Estrutura do Projeto

- **`Dockerfile`** – instala dependências gráficas, bibliotecas essenciais (libdrm, mesa, dbus-x11) e baixa o Postman 9.31.30 (pacote `linux64`).
- **`start.sh`** – inicia o servidor Xvfb, um daemon DBus de sessão, VNC/noVNC e o Postman apontando para `~/.config/Postman/Partitions`.
- **`docker-compose.yaml`** – define o serviço, portas, volume e a resolução da tela virtual via variável `RESOLUTION`.

O Postman é iniciado com as flags:
```

--disable-gpu --disable-dev-shm-usage --no-sandbox --disable-setuid-sandbox 
--disable-gpu-sandbox --disable-software-rasterizer --disable-features=VizDisplayCompositor 
--use-gl=swiftshader --in-process-gpu

````
Você pode sobrescrever essas opções via variável de ambiente `POSTMAN_FLAGS`.

---

## 🚀 Como Subir Localmente

1. (Opcional) Ajuste o caminho do volume no `docker-compose.yaml` conforme seu sistema:
   ```yaml
   volumes:
     - type: bind
       source: "${APPDATA}\\Postman\\Partitions"   # macOS: ~/Library/... | Linux: ~/.config/...
       target: /home/app/.config/Postman/Partitions
   ````

2. (Opcional) Ajuste a variável `RESOLUTION`:

   ```yaml
   environment:
     RESOLUTION: 1920x1080x24
   ```

3. Construa e suba o container:

   ```powershell
   docker compose up -d
   ```

4. Acesse no navegador:
   👉 [http://localhost:8080](http://localhost:8080)
![vnc_postman.png](assets%2Fvnc_postman.png)
   > Se o botão **"Skip and take me to Postman"** não aparecer, reduza o zoom (`Ctrl + -`) ou aumente a resolução.
   

5. Para parar o serviço:

   ```powershell
   docker compose down
   ```

---

## 📦 Publicação no Docker Hub

1. Login:

   ```powershell
   docker login 
   ```

2. Build e push multi-arquitetura:

   ```powershell
   docker buildx inspect --bootstrap
   docker run --privileged --rm tonistiigi/binfmt --install all

   docker buildx build --platform linux/amd64,linux/arm64   -t caiocf/postman-viewer:9.31.30_3  --push .
   ```

3. (Opcional) Limpeza de cache e camadas antigas:

   ```powershell
   docker buildx prune -af
   docker rmi caiocf/postman-viewer:9.31.30_3
   ```

---

## 🐳 Uso da Imagem do Docker Hub

Execute o container diretamente:

```powershell
docker run -d `
  --name postman-viewer `
  -p 8080:8080 `
  -e RESOLUTION=1920x1080x24 `
  -v "${ENV:APPDATA}\Postman\Partitions:/home/app/.config/Postman/Partitions" `
  caiocf/postman-viewer:9.31.30_3
```

> 💡 Para testar sem persistência, remova a opção `-v`.
> 🔒 O noVNC não usa HTTPS ou autenticação por padrão — limite o acesso à porta 8080 se for expor publicamente.

---

## ⚙️ Pontos de Atenção

* **Compatibilidade de dados:** partições de Postman 10+ não abrem na versão 9.31.30.
* **Backup:** sempre crie uma cópia da pasta `Partitions` antes de montar no container.
* **Logs:** se a interface não abrir, verifique:

  ```bash
  docker exec -it postman-viewer tail -f /tmp/postman.log
  ```
* **Desempenho:** aceleração de GPU está desativada por padrão; em hosts ARM pode haver pequena latência.
* **DBus:** o script inicia um DBus de sessão para evitar erros de comunicação.
* **Segurança:** configure firewall/VPN se publicar em rede externa.

---

## 🧪 Teste Local da Imagem

```bash
docker run --rm -it --platform linux/amd64 \
  caiocf/postman-viewer:9.31.30_3 \
  bash -lc 'dpkg --print-architecture; file /bin/bash'
```

---

## 🏷️ Licença

Distribuído sob a licença MIT. Veja o arquivo `LICENSE` para mais detalhes.

