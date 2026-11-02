# Atualização automática — EngenhariaArquitetura

## Situação e distribuição

A Central de Aplicativos verifica automaticamente, cerca de 4 segundos após abrir, se existe uma **release estável** mais recente no GitHub. Também oferece o comando **Verificar atualizações**.

As atualizações são feitas **a partir de pacotes binários de GitHub Releases**, e não baixando código-fonte de uma branch para sobrescrever executáveis. Um commit em `main` dispara o workflow `.github/workflows/release-updates.yml`, que tenta compilar o Linux e o Windows e publicar a release `v0.02.<numero-do-workflow>`.

O pacote somente é instalado se existir na release e se seu SHA-256 corresponder ao checksum publicado. Se a compilação ou o empacotamento de uma plataforma falhar, **não** haverá atualização dessa plataforma. Conferir as execuções do Actions antes de anunciar uma versão publicada.

## Windows

O instalador Inno Setup inclui a Central de Aplicativos, Planejador, CAD 2D, `build-manifest.json` e `updater/windows/update.ps1`.

- A Central executa o PowerShell em segundo plano, verificando o endpoint `/releases/latest` até uma vez ao dia; o botão permite forçar uma verificação.
- A versão local vem de `build-manifest.json`, comparada numericamente com a tag da última release estável.
- Somente é aceito um instalador `setup_engenhariaarquitetura_NNN.exe` acompanhado de `SHA256SUMS` da mesma release; o hash baixado é conferido antes de executar.
- O atualizador **espera o fechamento** da Central e dos módulos conhecidos. Não encerra à força programas com projetos possivelmente não salvos. Se o prazo expirar, a instalação não ocorre; nova verificação será necessária.
- O instalador é executado em modo silencioso com reinício desabilitado. Como a configuração atual instala em `Program Files` com `PrivilegesRequired=admin`, o Windows **pode solicitar autorização UAC**; sem autorização a atualização não será concluída.
- Log resumido: `%LOCALAPPDATA%\EngenhariaArquitetura\updates\status.json`.

**Primeira instalação:** uma versão existente sem o script atualizador precisa ser substituída **uma vez** por uma instalação que inclua o mecanismo. Depois, a verificação ocorre automaticamente.

## Linux x86_64

O workflow gera `engenhariaarquitetura-linux-x86_64.tar.gz` com os executáveis dos módulos compilados, o atualizador e `release-version.txt`, além de um arquivo `.sha256`.

- O script `updater/linux/update.py` usa Python 3.9+ e apenas bibliotecas padrão.
- Faz a comparação de versões, verifica o SHA-256 e rejeita caminhos inseguros ou links simbólicos dentro do arquivo.
- Instala versões na pasta do **usuário**, sem sobrescrever binários do sistema: `~/.local/share/EngenhariaArquitetura/versions/`.
- Atualiza o symlink `current` para a versão nova, preservando versões anteriores, e disponibiliza inicializadores em `~/.local/bin/`.
- Abra os aplicativos pelo inicializador `~/.local/bin/engenhariaarquitetura` (ou inclua `~/.local/bin` no `PATH`) para garantir que a próxima execução utilize a versão atual. Executar um binário antigo de outra pasta pode continuar abrindo esse binário antigo.
- Status em `~/.cache/EngenhariaArquitetura/updater.json`.

O instalador Linux não modifica uma instalação gerenciada por `apt`, `dpkg` ou administrador.

## Segurança, limites e testes

1. HTTPS e comparação SHA-256 protegem contra downloads corrompidos; checksum publicado pelo mesmo canal **não substitui assinatura digital independente**. Para produção Windows, recomenda-se assinatura Authenticode dos instaladores.
2. Não são baixadas alterações diretamente da branch `fila`. Somente releases produzidas após build e validação são elegíveis.
3. O workflow Linux executa os testes do atualizador e compila Launcher, Planejador e CAD 2D. O job Windows gera o instalador completo e valida a sintaxe do PowerShell, se as ferramentas estiverem disponíveis.
4. O updater não atualiza dados de projeto, bancos de dados ou configurações privadas.
5. Projetos não devem ser encerrados à força: atualizações Windows são instaladas somente após o fechamento dos processos conhecidos.
6. O comportamento de atualização e de reinicialização em equipamentos Windows/Linux reais ainda precisa de homologação final.

Comando local para testar a implementação Linux: `python3 -m unittest discover -s updater/tests -v`. Para investigar qualquer falha, consulte **GitHub Actions → Publicar atualizacoes EngenhariaArquitetura**.

## Publicação bloqueada por permissão do Actions

O workflow foi testado e a compilação dos pacotes Linux/Windows funcionou, mas o GitHub recusou a operação de criação de release com **HTTP 403 — Resource not accessible by integration**. Sem release publicada, o programa não tem um novo pacote confiável para instalar e **não consegue completar uma atualização automática**.

Para habilitar a publicação, no GitHub do repositório acesse **Settings → Actions → General → Workflow permissions**, selecione **Read and write permissions** e salve. O workflow já pede somente `contents: write`; se a conta/organização bloquear essa configuração, use um token de acesso com permissão **Contents: Read and write** restrita a este repositório como secret **EA_RELEASE_TOKEN** em **Settings → Secrets and variables → Actions**. Jamais publique o token em código, logs ou arquivos de configuração. Depois execute novamente o workflow **Publicar atualizacoes EngenhariaArquitetura**. Não há permissão de administração disponível na integração atual para alterar essa opção diretamente.
