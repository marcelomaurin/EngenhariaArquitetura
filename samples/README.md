# Hospital demonstrativo — CAD2D

Modelo original, fictício e didático de um térreo de 40 × 24 m, com 12 espaços: recepção, triagem, dois consultórios, farmácia, apoio/serviços, exames, diagnóstico, duas enfermarias, isolamento e circulação central. Não representa projeto executivo nem comprovação de atendimento a normas hospitalares.

## Arquivos em files

- hospital_terreo.eacad: formato nativo EACAD4, com formas, textos, cotas e mobiliário.
- hospital_terreo.ifc: IFC4, em metros, com geometria tridimensional e classificação dos componentes.
- hospital_terreo.dwg: DWG AutoCAD 2000, convertido pelo ODA File Converter 27.10.
- hospital_terreo.dxf: DXF AutoCAD 2000, em milímetros, usado para gerar o DWG.

No CAD2D, abra o EACAD e use Visualizar → Enquadrar tudo. O instalador inclui samples/files na pasta do aplicativo, cria um atalho no menu Iniciar e copia os modelos para Documentos/EngenhariaArquitetura Projetos/samples/files sem substituir arquivos existentes.

## Verificações e limites

IFC validado com IfcOpenShell e regras EXPRESS, sem erros; 91 objetos com geometria: 39 paredes, 13 portas, 11 janelas, 15 peças de mobiliário, 12 espaços e uma laje. A validação está em validacao-ifc.json. Aberturas são representadas por vãos entre segmentos de parede, sem relações IfcRelVoidsElement/IfcRelFillsElement.

Conversão DWG → DXF conferida com ezdxf: 206 entidades preservadas (166 linhas, 27 textos, 13 arcos), auditoria sem erros ou reparos. SHA256SUMS registra os arquivos distribuídos.

O importador IFC atual do CAD2D ainda produz uma representação esquemática, sem reconstruir a geometria completa do IFC. Use o EACAD para visualizar a planta fiel no aplicativo. A importação DWG depende de conversor externo compatível; o conversor ODA não é redistribuído. Cotas do CAD2D são independentes, sem associação paramétrica às paredes.

## Regeneração

Instale tools/requirements.txt e execute tools/generate_hospital.py para recriar EACAD, IFC, DXF e relatórios. Depois converta o DXF para DWG com o ODA File Converter e atualize SHA256SUMS. O gerador não produz DWG diretamente.

Referências: [IfcOpenShell](https://docs.ifcopenshell.org/), [ezdxf](https://ezdxf.readthedocs.io/), [ODA File Converter](https://www.opendesign.com/guestfiles/oda_file_converter).
