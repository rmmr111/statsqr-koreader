# StatsQR para KOReader (Kobo + Kindle)

O StatsQR é um plugin para KOReader em dispositivos **Kobo e Kindle** que partilha a base de dados `statistics.sqlite3` pela rede Wi‑Fi local e permite descarregá-la no telemóvel através de um QR code mostrado no dispositivo. O KOReader suporta Kindle e Kobo, e os plugins contrib são normalmente instalados na pasta `koreader/plugins` do dispositivo.

Este repositório é o **kit pronto para GitHub** com base na **v0.4.4**. O plugin resolve o ficheiro de estatísticas a partir da pasta de settings do KOReader no próprio código, em vez de fixar um caminho exclusivo do Kobo. A documentação atual do KOReader também expõe o módulo `datastorage`, que é a base transversal usada aqui.

![Exemplo do ecrã no dispositivo](docs/images/qr-screen-example.png)
![Exemplo da página no telemóvel](docs/images/phone-choice-example.png)

## O que faz

- Arranca um pequeno servidor HTTP local dentro do KOReader
- Resolve o ficheiro a partir da pasta de settings do KOReader:
  - `DataStorage:getSettingsDir() .. "/statistics.sqlite3"`
- Mostra um QR code no dispositivo
- Mostra um **número de 3 dígitos acima do QR code**
- Abre uma pequena página no telemóvel onde o utilizador tem de escolher o número correto entre 3 opções
- Permite descarregar apenas `statistics.sqlite3`
- Pára automaticamente ao fim de 2 minutos

## Caminhos mostrados na documentação

O StatsQR resolve o caminho real dinamicamente em execução, mas os exemplos “humanos” na documentação são:

- **Kobo:** `\.adds\koreader\settings\statistics.sqlite3`
- **Kindle:** `\koreader\settings\statistics.sqlite3`

## Versão atual

- Versão do plugin: **0.4.4**
- Estado: **release funcional em Kobo, variante preparada para Kindle**
- Localização no menu: **Settings → StatsQR**

## Estrutura do repositório

```text
statsqr-github-kit/
├── .github/workflows/package-release.yml
├── docs/images/
├── release/
├── scripts/
├── statsqr.koplugin/
├── CHANGELOG.md
├── LICENSE
├── README.md
└── README.pt-PT.md
```

## Instalação no Kobo

1. Faz download do ZIP de release na pasta `release/` ou nos GitHub Releases.
2. Extrai o ZIP.
3. Copia a pasta `statsqr.koplugin` para:

   ```text
   .adds/koreader/plugins/
   ```

4. Reinicia o KOReader.

## Instalação no Kindle

1. Faz download do ZIP de release na pasta `release/` ou nos GitHub Releases.
2. Extrai o ZIP.
3. Copia a pasta `statsqr.koplugin` para:

   ```text
   koreader/plugins/
   ```

4. Reinicia o KOReader.

## Como usar

No dispositivo:

1. Abre o menu superior.
2. Vai a **Settings**.
3. Abre **StatsQR**.
4. Toca em **Start sharing statistics.sqlite3**.
5. Lê o QR code com o telemóvel.
6. No telemóvel, escolhe o mesmo número de 3 dígitos que aparece acima do QR code no dispositivo.
7. O browser descarrega `statistics.sqlite3`.

Requisitos:

- Dispositivo e telemóvel na mesma rede Wi‑Fi
- Se o Wi‑Fi estiver desligado, o StatsQR pergunta se o deve ligar
- O KOReader deve ficar acordado até o download terminar

## Itens do menu

- **Start sharing statistics.sqlite3**
- **Stop sharing statistics.sqlite3**
- **Show QR code again**
- **Show current number**
- **Show direct URL**
- **About**

## Modelo de segurança na v0.4.4

O StatsQR foi pensado para **transferência local simples numa rede doméstica de confiança**.

Proteções atuais:

- Token temporário aleatório no caminho do URL
- Número aleatório de 3 dígitos mostrado no dispositivo
- O telemóvel tem de escolher o número certo antes do download
- Headers para evitar cache
- Headers de segurança no browser
- Paragem automática ao fim de 2 minutos

Limitação importante:

- A transferência continua a ser feita por **HTTP local**
- Alguns browsers no telemóvel podem mostrar aviso de **download não seguro**
- Esse aviso é esperado quando a transferência é feita por HTTP simples, mesmo em rede local

## Resolução de problemas

### A página não abre no telemóvel
- Confirma que os dois dispositivos estão na mesma rede Wi‑Fi
- Mantém o KOReader aberto e acordado
- Se o QR abrir numa pré-visualização embutida, escolhe **abrir no browser**
- Usa **Show direct URL** e escreve o endereço manualmente no telemóvel

### O Wi‑Fi está desligado ao tocar em Iniciar partilha
- O StatsQR pergunta se queres ligar o Wi‑Fi
- Depois da confirmação, o plugin pede ao KOReader para ativar o Wi‑Fi e tenta continuar automaticamente
- Se o dispositivo não voltar a ligar-se a tempo, liga manualmente e tenta outra vez

### Aviso de download não seguro
- Esta versão usa HTTP local, não HTTPS
- Alguns browsers avisam em downloads locais inseguros
- O plugin continua a funcionar, mas o aviso pode aparecer

### O ficheiro não existe
- O StatsQR procura:
  - `DataStorage:getSettingsDir() .. "/statistics.sqlite3"`
- Exemplos de caminho apresentados ao utilizador:
  - Kobo: `\.adds\koreader\settings\statistics.sqlite3`
  - Kindle: `\koreader\settings\statistics.sqlite3`
- Abre o KOReader normalmente e confirma que as estatísticas já foram geradas

### Porta já em uso
- A porta por omissão é `8765`
- Mais tarde isto pode ser tornado configurável no plugin

## Como gerar o ZIP de release

Na raiz do repositório:

```bash
bash scripts/package-release.sh
```

Isto cria um ZIP novo na pasta `release/` contendo apenas:

```text
statsqr.koplugin/
```

## Como publicar no GitHub

Passos recomendados:

1. Criar um novo repositório no GitHub
2. Enviar o conteúdo deste kit
3. Fazer commit e push
4. Criar um GitHub Release com o nome `v0.4.4`
5. Anexar o ZIP `release/statsqr.koplugin.v0.4.4.zip`

Nome sugerido para o repositório:

```text
statsqr-koreader
```

Tópicos sugeridos:

```text
koreader
kobo
kindle
lua
plugin
ereader
qr-code
statistics
```

## Licença

Este kit inclui uma licença MIT como ponto de partida. Podes trocar por outra se preferires.

## Texto exemplo para GitHub Release

Há uma nota de release pronta a colar em:

```text
release/RELEASE_NOTES_v0.4.4.md
```
