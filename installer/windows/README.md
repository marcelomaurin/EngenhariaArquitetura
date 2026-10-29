# Instalador Windows — EngenhariaArquitetura

Windows 64 bits, Git, Python 3.9+ com Pillow, Lazarus/Free Pascal 64 bits e Inno Setup 6.3 ou superior.

## Gerar no Windows

    installer\windows\build_release.bat -Version 0.01 -SetupSeq 001

Sem parâmetros, a versão e a sequência vêm de [installer/VERSION.ini](../VERSION.ini). O script procura as ferramentas nas pastas usuais; os caminhos podem ser definidos pelas variáveis LAZBUILD, FPC, PYTHON e ISCC. EA_CHATGPT_DIR aponta para o repositório CHATGPT quando ele não estiver ao lado deste (padrão: `..\CHATGPT`).

A publicação exige árvore Git limpa. Para gerar e testar um instalador local antes do commit, acrescente `-AllowDirty`; o manifesto registra `source_dirty=true`.

## Gerar no Linux (compilação cruzada)

    ISCC=/caminho/ISCC.exe installer/windows/build_release_wine.sh 0.01 001

Mesmos passos do `build_release.ps1`:

1. compila os executáveis win64 com o FPC/Lazarus do Linux (unidades x86_64-win64 do RTL e dos pacotes instaladas);
2. roda os testes de console win64 no Wine;
3. copia documentação, exemplos e licenças para `dist\app`;
4. gera o manifesto e as imagens do instalador (`prepare_images.py`, com Pillow);
5. gera o instalador com o ISCC.exe do Inno Setup no Wine (32 e 64 bits).

O Wine precisa de localidade UTF-8 para criar atalhos com acento; o script define `C.UTF-8` quando nenhuma estiver configurada.

## Saídas

| Arquivo | Conteúdo |
|---|---|
| `bin\planejador.exe` | Planejador para Windows 64 bits |
| `bin\setup_engenhariaarquitetura_NNN.exe` | Instalador |
| `setup\setup_engenhariaarquitetura_NNN.exe` | Cópia do instalador publicada |
| `setup\SHA256SUMS` | Somas de verificação dos instaladores |
| `setup\build-manifest-NNN.json` | Versão, commit de origem, testes e soma de cada arquivo instalado |
| `setup\qa-tests-NNN.json` | Resultado dos testes de console |
| `dist\` | Área de montagem e registros da compilação (não versionada) |

## Conteúdo do instalador

| Componente | Itens | Instalação básica |
|---|---|---|
| Aplicativos | Planejador | Sim (obrigatório) |
| Projetos de exemplo | `residencia.plan.json`, também copiado para `Documentos\EngenhariaArquitetura Projetos\Exemplos` | Não |
| Documentação | README e todos os documentos de `docs` | Não |

O instalador cria o grupo **EngenhariaArquitetura** no menu Iniciar (Planejador, Planejador com o exemplo da residência e Documentação), oferece atalho na área de trabalho e, ao final, abre o Planejador com o exemplo. A desinstalação remove arquivos e atalhos e preserva os projetos do usuário em Documentos.

Os próximos aplicativos da plataforma entram como novos componentes em `engenhariaarquitetura.iss` e novas linhas em `TARGETS` dos dois scripts de geração.

## Validação

Não distribuir um instalador se a compilação ou os testes falharem. A versão 0.01 (sequência 001) e a 0.02 (002) foram geradas no Linux pelo `build_release_wine.sh` e testadas no Wine: assistente em português, instalação completa, atalhos, abertura do Planejador instalado com o exemplo e desinstalação. O `build_release.ps1` segue os mesmos passos, mas ainda não foi executado no Windows.
