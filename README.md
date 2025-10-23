Postman GUI via Docker com Persistência (versão 9.31.30)
=======================================================

Este projeto entrega o Postman GUI rodando em um container Debian minimalista, acessível via navegador (noVNC). A imagem instala a versão 9.31.30, que ainda permite utilizar o aplicativo sem login obrigatório. As coleções e ambientes são preservados mapeando o diretório `Partitions` do Postman do host para o container.

> **Importante:** a versão 9.31.30 não abre partições criadas por versões mais novas (Postman 10+). Se seus dados são de uma versão mais recente, exporte suas coleções como JSON usando um Postman compatível antes de migrar para esta imagem. Sempre faça backup da pasta `Partitions` antes de experimentar.

Requisitos
----------

- Docker 20.10+ e Docker Compose Plugin.
- Windows: diretório `%APPDATA%\Postman\Partitions` existente (ou exporte manualmente as coleções para importar depois).  
  - macOS: `~/Library/Application Support/Postman/Partitions`.  
  - Linux: `~/.config/Postman/Partitions`.  
- macOS Apple Silicon (M1/M2): Docker Desktop com suporte a emulação `linux/amd64` habilitado (o compose já força essa arquitetura).

Estrutura do projeto
--------------------

- `Dockerfile.amd64`: instala dependências gráficas, bibliotecas adicionais (libdrm, mesa, dbus-x11), baixa o Postman 9.31.30 (pacote `linux64`) e prepara o usuário `app` para hosts x86_64.
- `Dockerfile.arm64`: equivalente para hosts ARM64, baixando o pacote `linux-arm64` (por padrão a versão `latest`, que exige login no Postman 10+).
- `start.sh`: sobe Xvfb, inicia um daemon DBus de sessão, VNC/noVNC e lança o Postman apontando para `~/.config/Postman/Partitions`.
- O script já liga o Postman com flags `--disable-gpu --disable-dev-shm-usage --no-sandbox --disable-setuid-sandbox --disable-gpu-sandbox --disable-software-rasterizer --disable-features=VizDisplayCompositor --use-gl=swiftshader --in-process-gpu`; personalize via variável `POSTMAN_FLAGS` se necessário.
- `docker-compose.yaml`: define o serviço, mapeia portas/volume e ajusta resolução do display virtual.

Arquiteturas suportadas
-----------------------

- **x86_64 (amd64):** utilize o `Dockerfile.amd64`, que preserva a versão 9.31.30 (sem login obrigatório) baixando o pacote `linux64`.
- **ARM64 (aarch64/Apple Silicon):** utilize o `Dockerfile.arm64`, que baixa o pacote `linux-arm64`. A Postman mantém apenas versões 10+ para ARM, portanto será necessário autenticar-se ao abrir o aplicativo.

Como subir localmente
---------------------

1. Ajuste o caminho do volume no `docker-compose.yaml` conforme seu sistema operacional (Windows já está configurado).  
   ```yaml
   volumes:
     - type: bind
       source: "${APPDATA}\\Postman\\Partitions"   # ajuste para macOS/Linux conforme comentários
       target: /home/app/.config/Postman/Partitions
   ```
2. (Opcional) Ajuste a variável `RESOLUTION` para aumentar a área útil do Postman, por exemplo `1920x1080x24`.
3. Construa e suba o container (em hosts ARM64 exporte `POSTMAN_DOCKERFILE=Dockerfile.arm64` e `POSTMAN_PLATFORM=linux/arm64` antes do comando):
   ```powershell
   docker compose up --build -d
   ```
4. Abra `http://localhost:8080` no navegador. O botão “Skip and take me to Postman” só aparece com a resolução suficiente; use as teclas `Ctrl` + `-` ou aumente `RESOLUTION` se necessário.
5. Para parar:
   ```powershell
   docker compose down
   ```

Publicação no Docker Hub
------------------------

1. Faça login:
   ```powershell
   docker login -u caiocf
   ```
2. Construa e publique a variante **amd64**:
   ```powershell
   docker build -f Dockerfile.amd64 -t caiocf/postman-viewer:9.31.30-amd64 .
   docker push caiocf/postman-viewer:9.31.30-amd64
   docker tag  caiocf/postman-viewer:9.31.30-amd64 caiocf/postman-viewer:latest-amd64
   docker push caiocf/postman-viewer:latest-amd64
   ```
3. Construa e publique a variante **arm64** (execute em um host ARM ou habilite `buildx` com emulação QEMU):
   ```powershell
   docker build -f Dockerfile.arm64 -t caiocf/postman-viewer:9.31.30-arm64 .
   docker push caiocf/postman-viewer:9.31.30-arm64
   docker tag  caiocf/postman-viewer:9.31.30-arm64 caiocf/postman-viewer:latest-arm64
   docker push caiocf/postman-viewer:latest-arm64
   ```
4. (Opcional) Gere um manifest multi-arquitetura para facilitar o `docker pull` automático:
   ```powershell
   docker manifest create caiocf/postman-viewer:9.31.30 `
     --amend caiocf/postman-viewer:9.31.30-amd64 `
     --amend caiocf/postman-viewer:9.31.30-arm64
   docker manifest push caiocf/postman-viewer:9.31.30

   docker manifest create caiocf/postman-viewer:latest `
     --amend caiocf/postman-viewer:latest-amd64 `
     --amend caiocf/postman-viewer:latest-arm64
   docker manifest push caiocf/postman-viewer:latest
   ```

Uso da imagem do Docker Hub
---------------------------

```powershell
docker run -d `
  --name postman-viewer `
  -p 8080:8080 `
  -e RESOLUTION=1920x1080x24 `
  -v "${ENV:APPDATA}\Postman\Partitions:/home/app/.config/Postman/Partitions" `
  caiocf/postman-viewer:9.31.30
```

- Para macOS/Linux, substitua o volume conforme caminho indicado no topo.
- Se quiser apenas testar sem persistência, remova a opção `-v`.
- Desligar:
  ```powershell
  docker stop postman-viewer && docker rm postman-viewer
  ```

      
    # windows: substitua a origem por '${APPDATA}\\Postman\\Partitions'
    # macOS: substitua a origem por '$HOME/Library/Application Support/Postman/Partitions'
    # Linux: substitua por '$HOME/.config/Postman/Partitions'

Pontos de atenção
-----------------

- **Compatibilidade de dados:** partições de Postman 10+ não abrem na 9.31.30. Exporte/importe coleções se estiver migrando.
- **Backup:** antes de montar `Partitions` no container, crie uma cópia de segurança.
- **Log do Postman:** se a interface não abrir, verifique `/tmp/postman.log` dentro do container (`docker exec -it postman-viewer tail -f /tmp/postman.log`).
- **Desempenho:** o Postman roda com aceleração de GPU desabilitada (flags padrão em `start.sh`); em hardware limitado ou sob emulação ARM, pode haver latência na interface via noVNC.
- **DBus/Logs:** o script inicia um DBus de sessão para evitar “Failed to connect to the bus”. Se ainda vir mensagens `gpu_process_host`, abra `/tmp/postman.log` para validar se as flags foram aplicadas e ajuste `POSTMAN_FLAGS`.
- **Segurança:** noVNC não usa HTTPS nem autenticação por padrão. Restrinja o acesso à porta 8080 (VPN, firewall, etc.) ao publicar em ambientes públicos.
