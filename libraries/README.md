# Bibliotecas 2D — saúde e uso geral

O CAD é de uso geral, com direcionamento para hospitais, UBS e outros centros
assistenciais, especialmente projetos destinados ao SUS. O catálogo não restringe
o uso residencial, comercial, industrial ou outros programas de arquitetura.

`catalogo_2d.json` contém 48 itens vetoriais em milímetros, agrupados por categoria:
consultórios e avaliação; diagnóstico/procedimentos; laboratório/coleta;
vacinação/farmácia; internação/observação; urgência; odontologia;
esterilização/apoio; recepção/acessibilidade; e uso geral.

As geometrias são símbolos e envelopes iniciais editáveis criados para este
software. As dimensões **não são mínimos normativos nem fichas de fabricante**.
Confirme o equipamento real, seu espaço operacional, instalações e manutenção.
O campo `dimension_status` identifica essa condição e `clinical_validation`
informa que o item não foi avaliado quanto à conformidade clínica/normativa.

Cada item possui ID estável, nome, categoria, largura/profundidade iniciais,
primitivas vetoriais e referência de planejamento. A referência SOMASUS orienta
a pesquisa do programa de necessidades; os valores desta biblioteca não foram
extraídos como especificações certificadas desse sistema.

No CAD: Biblioteca → Mobiliário e equipamentos → escolher categoria/item →
ajustar dimensões → Inserir → clicar no desenho. Mover, copiar, girar, espelhar,
redimensionar e excluir atuam no bloco completo. Desagrupar converte o bloco
em segmentos. A geometria e o ID são preservados no projeto EACAD5, mesmo sem
o catálogo externo disponível na máquina que abrir o arquivo.

O exemplo geral e as ferramentas de desenho continuam disponíveis. O catálogo
é extensível por JSON: mantenha IDs únicos e estáveis, unidade mm e o esquema
de primitivas (line, rect, ellipse) usado pelos itens existentes.

Referências: [SOMASUS](https://somasus.saude.gov.br/index.html),
[Projetos referenciais de UBS — FNS](https://portalfns.saude.gov.br/novo-pac-saude-disponibiliza-projetos-de-referencia-para-ubs-em-5-portes/).
