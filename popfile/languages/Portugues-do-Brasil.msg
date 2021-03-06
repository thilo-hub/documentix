# Copyright (c) 2001-2011 John Graham-Cumming
# Translated by Adriano Rafael Gomes <adrianorg@users.sourceforge.net>
# Updated by Fernando de Alcantara Correia <facorreia@users.sourceforge.net> to v0.19.1
#
#   This file is part of POPFile
#
#   POPFile is free software; you can redistribute it and/or modify it
#   under the terms of version 2 of the GNU General Public License as
#   published by the Free Software Foundation.
#
#   POPFile is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with POPFile; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

# Identify the language and character set used for the interface
LanguageCode                            br
LanguageCharset                         ISO-8859-1
LanguageDirection                       ltr

# This is used to get the appropriate subdirectory for the manual
ManualLanguage                          br

# This is where to find the FAQ on the Wiki
FAQLink                                 FAQ

# Common words that are used on their own all over the interface
Apply                                   Aplicar
ApplyChanges                            Aplicar Altera��es
On                                      Ligado
Off                                     Desligado
TurnOn                                  Ligar
TurnOff                                 Desligar
Add                                     Adicionar
Remove                                  Remover
Previous                                Anterior
Next                                    Pr�ximo
From                                    De
Subject                                 Assunto
Cc                                      Cc
Classification                          Balde
Reclassify                              Reclassificar
Probability                             Probabilidade
Scores                                  Pontos
QuickMagnets                            �m�s R�pidos
Undo                                    Desfazer
Close                                   Fechar
Find                                    Procurar
Filter                                  Filtrar
Yes                                     Sim
No                                      N�o
ChangeToYes                             Trocar para Sim
ChangeToNo                              Trocar para N�o
Bucket                                  Balde
Magnet                                  �m�
Delete                                  Excluir
Create                                  Criar
To                                      Para
Total                                   Total
Rename                                  Renomear
Frequency                               Freq��ncia
Probability                             Probabilidade
Score                                   Pontua��o
Lookup                                  Procurar
Word                                    Palavra
Count                                   Quantidade
Update                                  Alterar
Refresh                                 Atualizar
FAQ                                     FAQ
ID                                      ID
Date                                    Data
Arrived                                 Chegada
Size                                    Tamanho

# This is a regular expression pattern that is used to convert
# a number into a friendly looking number (for the US and UK this
# means comma separated at the thousands)

Locale_Thousands                       .
Locale_Decimal                         ,

# The Locale_Date uses the format strings in Perl's Date::Format
# module to set the date format for the UI.  There are two possible
# ways to specify it.
#
# <format>            Just one simple format used for all dates
# <format> | <format> The first format is used for dates less than
#                     7 days from now, the second for all other dates

Locale_Date                            %a %R | %D %R

# The header and footer that appear on every UI page
Header_Title                            Centro de Controle do POPFile
Header_Shutdown                         Desligar o POPFile
Header_History                          Hist�rico
Header_Buckets                          Baldes
Header_Configuration                    Configura��o
Header_Advanced                         Avan�ado
Header_Security                         Seguran�a
Header_Magnets                          �m�s

Footer_HomePage                         POPFile Home Page
Footer_Manual                           Manual
Footer_Forums                           Forums
Footer_FeedMe                           Contribua
Footer_RequestFeature                   Pedir uma Caracter�stica
Footer_MailingList                      Lista de Email
Footer_Wiki                             Documenta��o

Configuration_Error1                    O caracter separador deve ser um �nico caracter
Configuration_Error2                    O porta da interface de usu�rio deve ser um n�mero entre 1 e 65535
Configuration_Error3                    A porta de escuta POP3 deve ser um n�mero entre 1 e 65535
Configuration_Error4                    O tamanho da p�gina deve ser um n�mero entre 1 e 1000
Configuration_Error5                    O n�mero de dias no hist�rico deve ser um n�mero entre 1 e 366
Configuration_Error6                    O tempo limite TCP deve ser um n�mero entre 10 e 1800
Configuration_Error7                    A porta de escuta XML-RPC deve ser um n�mero entre 1 e 65535
Configuration_Error8                    A porta do proxy SOCKS V deve ser um n�mero entre 1 e 65535
Configuration_POP3Port                  Porta de escuta POP3
Configuration_POP3Update                A porta POP3 foi alterada para %s; esta altera��o n�o ter� efeito at� que voc� reinicie o POPFile
Configuration_XMLRPCUpdate              A porta XML-RPC foi alterada para %s; esta altera��o n�o ter� efeito at� que voc� reinicie o POPFile
Configuration_XMLRPCPort                Porta de escuta XML-RPC
Configuration_SMTPPort                  Porta de escuta SMTP
Configuration_SMTPUpdate                A porta SMTP foi alterada para %s; esta altera��o n�o ter� efeito at� que voc� reinicie o POPFile
Configuration_NNTPPort                  Porta de escuta NNTP
Configuration_NNTPUpdate                A porta NNTP foi alterada para %s; esta altera��o n�o ter� efeito at� que voc� reinicie o POPFile
Configuration_POPFork                   Permitir conex�es POP3 concorrentes
Configuration_SMTPFork                  Permitir conex�es SMTP concorrentes
Configuration_NNTPFork                  Permitir conex�es NNTP concorrentes
Configuration_POP3Separator             Caracter de separa��o POP3 servidor:porta:usu�rio
Configuration_NNTPSeparator             Caracter de separa��o NNTP servidor:porta:usu�rio
Configuration_POP3SepUpdate             Separador POP3 alterado para %s
Configuration_NNTPSepUpdate             Separador NNTP alterado para %s
Configuration_UI                        Porta da interface web de usu�rio
Configuration_UIUpdate                  Alterada a porta da interface web de usu�rio para %s; esta altera��o n�o ter� efeito at� que voc� reinicie o POPFile
Configuration_History                   N�mero de mensagens por p�gina
Configuration_HistoryUpdate             Alterado o n�mero de mensagens por p�gina para %s
Configuration_Days                      N�mero de dias para manter no hist�rico
Configuration_DaysUpdate                Alterado o n�mero de dias para manter no hist�rico para %s
Configuration_UserInterface             Interface de Usu�rio
Configuration_Skins                     Skins
Configuration_SkinsChoose               Escolha o skin
Configuration_Language                  Linguagem
Configuration_LanguageChoose            Escolha a linguagem
Configuration_ListenPorts               Op��es de M�dulo
Configuration_HistoryView               Exibir Hist�rico
Configuration_TCPTimeout                Tempo Limite de Conex�o
Configuration_TCPTimeoutSecs            Tempo limite de conex�o em segundos
Configuration_TCPTimeoutUpdate          Alterado o tempo limite de conex�o para %s
Configuration_ClassificationInsertion   Inser��o de Texto na Mensagem
Configuration_SubjectLine               Modifica��o de<br>linha de assunto
Configuration_XTCInsertion              Cabe�alho<br>X-Text-Classification
Configuration_XPLInsertion              Cabe�alho<br>X-POPFile-Link
Configuration_Logging                   Logging
Configuration_None                      Nada
Configuration_ToScreen                  Na Tela (console)
Configuration_ToFile                    Em Arquivo
Configuration_ToScreenFile              Na Tela e em Arquivo
Configuration_LoggerOutput              Sa�da do Logger
Configuration_GeneralSkins              Skins
Configuration_SmallSkins                Small Skins
Configuration_TinySkins                 Tiny Skins
Configuration_CurrentLogFile            &lt;Exibir arquivo de log atual&gt;
Configuration_SOCKSServer               Endere�o do proxy SOCKS V
Configuration_SOCKSPort                 Porta do proxy SOCKS V
Configuration_SOCKSPortUpdate           Alterada a porta do proxy SOCKS V para %s
Configuration_SOCKSServerUpdate         Alterado o endere�o do proxy SOCKS V para %s
Configuration_Fields                    Colunas do Hist�rico

Advanced_Error1                         '%s' j� est� na lista de Palavras Ignoradas
Advanced_Error2                         Palavras ignoradas podem somente conter caracteres alfanum�ricos, ., _, -, ou @
Advanced_Error3                         '%s' adicionado na lista de Palavras Ignoradas
Advanced_Error4                         '%s' n�o est� na lista de Palavras Ignoradas
Advanced_Error5                         '%s' removido da lista de Palavras Ignoradas
Advanced_StopWords                      Palavras Ignoradas
Advanced_Message1                       O POPFile ignora as seguintes palavras freq�entemente usadas:
Advanced_AddWord                        Adicionar palavra
Advanced_RemoveWord                     Remover palavra
Advanced_AllParameters                  Todos os Par�metros do POPFile
Advanced_Parameter                      Par�metro
Advanced_Value                          Valor
Advanced_Warning                        Esta � a lista completa dos par�metros do POPFile.  Somente para usu�rios avan�ados: voc� pode alterar qualquer um e clicar em Alterar; n�o h� verifica��o de validade.  �tens em negrito est�o diferentes da configura��o padr�o. Veja <a href="http://getpopfile.org/docs/OptionReference">OptionReference</a> para mais informa��o sobre as op��es.
Advanced_ConfigFile                     Arquivo de configura��o:

History_Filter                          &nbsp;(apenas mostrando o balde <font color="%s">%s</font>)
History_FilterBy                        Filtrar Por
History_Search                          &nbsp;(procurado por remetente/assunto %s)
History_Title                           Mensagens Recentes
History_Jump                            Ir para a p�gina
History_ShowAll                         Exibir Tudo
History_ShouldBe                        Deveria ser
History_NoFrom                          sem linha de
History_NoSubject                       sem linha de assunto
History_ClassifyAs                      Classificar como
History_MagnetUsed                      �m� usado
History_MagnetBecause                   <b>�m� Utilizado</b><p>Classificado para <font color="%s">%s</font> por causa do �m� %s </p>
History_ChangedTo                       Alterado para <font color="%s">%s</font>
History_Already                         Reclassificado como <font color="%s">%s</font>
History_RemoveAll                       Remover Tudo
History_RemovePage                      Remover a P�gina
History_RemoveChecked                   Remover Marcados
History_Remove                          Para remover entradas do hist�rico clique
History_SearchMessage                   Procurar Remetente/Assunto
History_NoMessages                      Nenhuma mensagem
History_ShowMagnet                      magnetizado
History_Negate_Search                   Inverter procura/filtro
History_Magnet                          &nbsp;(mostrando apenas mensagens classificadas por �m�)
History_NoMagnet                        &nbsp;(mostrando apenas mensagens n�o classificadas por �m�)
History_ResetSearch                     Limpar
History_ChangedClass                    Deveria classificar agora como
History_Purge                           Expirar Agora
History_Increase                        Incrementar
History_Decrease                        Decrementar
History_Column_Characters               Alterar a largura das colunas De, Para, Cc e Assunto
History_Automatic                       Autom�tico
History_Reclassified                    Reclassificado
History_Size_Bytes                      %d&nbsp;B
History_Size_KiloBytes                  %.1f&nbsp;KB
History_Size_MegaBytes                  %.1f&nbsp;MB

Password_Title                          Senha
Password_Enter                          Digite a senha
Password_Go                             Ir!
Password_Error1                         Senha incorreta

Security_Error1                         A porta deve ser um n�mero entre 1 e 65535
Security_Stealth                        Modo Stealth/Opera��o Servidor
Security_NoStealthMode                  N�o (Modo Stealth)
Security_StealthMode                    (Modo Stealth)
Security_ExplainStats                   (Com isto ligado o POPFile envia uma vez por dia os seguintes tr�s valores para um script em getpopfile.org: bc (o n�mero total de baldes que voc� tem), mc (o n�mero total de mensagens que o POPFile classificou) e ec (o n�mero total de erros de classifica��o).  Isto fica guardado em um arquivo e eu vou usar para publicar algumas estat�sticas sobre como as pessoas usam o POPFile e o qu�o bem ele funciona.  Meu servidor web mant�m seus arquivos de log por mais ou menos 5 dias e ent�o os deleta; eu n�o estou guardando nenhuma conex�o entre as estat�stcas e os endere�os IP de cada um.)
Security_ExplainUpdate                  (Com isto ligado o POPFile envia uma vez por dia os seguintes tr�s valores para um script em getpopfile.org: ma (o n�mero maior da vers�o do seu POPFile), mi (o n�mero menor da vers�o do seu POPFile) e bn (o n�mero do build da sua vers�o do POPFile). O POPFile recebe uma resposta na forma de um gr�fico que aparece no topo da p�gina se uma nova vers�o estiver dispon�vel.  Meu servidor web mant�m seus arquivos de log por mais ou menos 5 dias e ent�o os deleta; eu n�o estou guardando nenhuma conex�o entre as verifica��es de vers�o e os endere�os IP de cada um.)
Security_PasswordTitle                  Senha da Interface de Usu�rio
Security_Password                       Senha
Security_PasswordUpdate                 Alterada a senha
Security_AUTHTitle                      Servidores Remotos
Security_SecureServer                   Servidor POP3 remoto (SPA/AUTH ou proxy transparente)
Security_SecureServerUpdate             Alterado o servidor POP3 remoto para %s
Security_SecurePort                     Porta POP3 remota (SPA/AUTH ou proxy transparente)
Security_SecurePortUpdate               Alterada a porta do servidor POP3 remoto para %s
Security_SMTPServer                     Servidor da cadeia SMTP
Security_SMTPServerUpdate               Alterado o servidor da cadeia SMTP para %s; esta altera��o n�o ter� efeito at� que voc� reinicie o POPFile
Security_SMTPPort                       Porta da cadeia SMTP
Security_SMTPPortUpdate                 Alterada a porta da cadeia SMTP para %s; esta altera��o n�o ter� efeito at� que voc� reinicie o POPFile
Security_POP3                           Aceitar conex�es POP3 de m�quinas remotas (requer reiniciar o POPFile)
Security_SMTP                           Aceitar conex�es SMTP de m�quinas remotas (requer reiniciar o POPFile)
Security_NNTP                           Aceitar conex�es NNTP de m�quinas remotas (requer reiniciar o POPFile)
Security_UI                             Aceitar conex�es HTTP (Interface de Usu�rio) de m�quinas remotas (requer reiniciar o POPFile)
Security_XMLRPC                         Aceitar conex�es XML-RPC de m�quinas remotas (requer reiniciar o POPFile)
Security_UpdateTitle                    Verifica��o Autom�tica de Atualiza��o
Security_Update                         Verificar diariamente atualiza��es para o POPFile
Security_StatsTitle                     Reportar Estat�sticas
Security_Stats                          Enviar estat�sticas diariamente

Magnet_Error1                           �m� '%s' j� existe no balde '%s'
Magnet_Error2                           O novo �m� '%s' conflita com o �m� '%s' no balde '%s' e pode causar resultados amb�guos.  O novo �m� n�o foi adicionado.
Magnet_Error3                           Criar novo �m� '%s' no balde '%s'
Magnet_CurrentMagnets                   �m�s Atuais
Magnet_Message1                         Os seguintes �m�s fazem as mensagens serem sempre classificadas no balde especificado.
Magnet_CreateNew                        Criar Novo �m�
Magnet_Explanation                      Estes tipos de �m� est�o dispon�veis: <ul><li><b>Endere�o ou nome do remetente:</b> Por exemplo: fulano@empresa.com para pegar um endere�o espec�fico, <br />empresa.com para pegar todo mundo que envia de empresa.com, <br />Fulano de Tal para pegar uma pessoa espec�fica, Fulano para pegar todos os Fulanos.</li><li><b>Endere�o ou nome de destinat�rio/c�pia:</b> Como um �m� de remetente mas para o endere�o Para:/Cc: de uma mensagem.</li> <li><b>Palavras no assunto:</b> Por exemplo: ol� para pegar todas as mensagens com ol� no assunto.</li></ul>
Magnet_MagnetType                       Tipo do �m�
Magnet_Value                            Valores
Magnet_Always                           Sempre vai para o balde
Magnet_Jump                             Ir para a p�gina de �m�s

Bucket_Error1                           Nomes de balde somente podem conter as letras de a at� z min�sculas, n�meros de 0 a 9, mais - e _
Bucket_Error2                           O balde %s j� existe
Bucket_Error3                           Criado o balde %s
Bucket_Error4                           Por favor digite uma palavra que n�o seja em branco
Bucket_Error5                           Renomeado o balde %s para %s
Bucket_Error6                           Exclu�do o balde %s
Bucket_Title                            Configura��o do Balde
Bucket_BucketName                       Nome do<br>Balde
Bucket_WordCount                        Contagem de Palavras
Bucket_WordCounts                       Contagens de Palavras
Bucket_UniqueWords                      Palavras Distintas
Bucket_SubjectModification              Modifica��o do<br>Cabe�alho Assunto
Bucket_ChangeColor                      Cor do<br>Balde
Bucket_NotEnoughData                    Dados insuficientes
Bucket_ClassificationAccuracy           Precis�o da Classifica��o
Bucket_EmailsClassified                 Mensagens classificadas
Bucket_EmailsClassifiedUpper            Mensagens Classificadas
Bucket_ClassificationErrors             Erros de classifica��o
Bucket_Accuracy                         Precis�o
Bucket_ClassificationCount              Contagem da Classifica��o
Bucket_ClassificationFP                 Falsos Positivos
Bucket_ClassificationFN                 Falsos Negativos
Bucket_ResetStatistics                  Reiniciar Estat�sticas
Bucket_LastReset                        �ltimo Rein�cio
Bucket_CurrentColor                     A cor atual de %s � %s
Bucket_SetColorTo                       Ajustar a cor de %s para %s
Bucket_Maintenance                      Manuten��o
Bucket_CreateBucket                     Criar balde com o nome
Bucket_DeleteBucket                     Excluir o balde chamado
Bucket_RenameBucket                     Renomear o balde chamado
Bucket_Lookup                           Procurar
Bucket_LookupMessage                    Procurar por palavra nos baldes
Bucket_LookupMessage2                   Procurar no resultado por
Bucket_LookupMostLikely                 <b>%s</b> � mais prov�vel de aparecer em <font color="%s">%s</font>
Bucket_DoesNotAppear                    <p><b>%s</b> n�o aparece em nenhum dos baldes
Bucket_DisabledGlobally                 Desabilitado globalmente
Bucket_To                               para
Bucket_Quarantine                       Mensagem de<br>Quarentena

SingleBucket_Title                      Detalhes para %s
SingleBucket_WordCount                  Contagem de palavras do balde
SingleBucket_TotalWordCount             Contagem total de palavras
SingleBucket_Percentage                 Percentual do total
SingleBucket_WordTable                  Tabela de Palavras para %s
SingleBucket_Message1                   Clique em uma letra no �ndice para ver a lista de palavras que come�am com tal letra.  Clique em qualquer palavra para procurar sua probabilidade para todos os baldes.
SingleBucket_Unique                     %s distinta
SingleBucket_ClearBucket                Remover Todas Palavras

Session_Title                           Sess�o do POPFile Expirada
Session_Error                           A sua sess�o do POPFile expirou.  Isto pode ter sido causado por iniciar e parar o POPFile mas deixando o navegador web aberto.  Por favor clique em um dos atalhos acima para continuar a usar o POPFile.

View_Title                              Vis�o de �nica Mensagem
View_ShowFrequencies                    Exibir freq��ncia das palavras
View_ShowProbabilities                  Exibir probabilidade das palavras
View_ShowScores                         Exibir pontua��o das palavras e gr�fico de decis�o
View_WordMatrix                         Matriz de palavras
View_WordProbabilities                  exibindo probabilidade das palavras
View_WordFrequencies                    exibindo freq��ncia das palavras
View_WordScores                         exibindo pontua��o das palavras
View_Chart                              Gr�fico de Decis�o

Windows_TrayIcon                        Exibir o �cone do POPFile na bandeja do sistema?
Windows_Console                         Executar o POPFile em uma janela de console?
Windows_NextTime                        <p><font color="red">Esta altera��o n�o ter� efeito at� que voc� reinicie o POPFile</font>

Header_MenuSummary                      Esta tabela � o menu de navega��o que possibilita acesso a cada uma das diferentes p�ginas do centro de controle.
History_MainTableSummary                Esta tabela mostra o remetente e o assunto das mensagens recebidas recentemente e permite que elas sejam revisadas e reclassificadas.  Clicar na linha de assunto vai mostrar o texto inteiro da mensagem, juntamente com informa��o sobre por que ela foi classificada como o foi.  A coluna 'Deveria ser' permite que voc� especifique a que balde a mensagem pertence, ou desfazer esta mudan�a.  A coluna 'Remover' permite que voc� exclua mensagens espec�ficas do hist�rico se voc� n�o precisar mais delas.
History_OpenMessageSummary              Esta tabela cont�m o texto integral de uma mensagem, com as palavras que s�o usadas para classifica��o destacadas de acordo com o balde que foi mais relevante para elas.
Bucket_MainTableSummary                 Esta tabela fornece uma vis�o geral dos baldes de classifica��o.  Cada linha mostra o nome do balde, a contagem total de palavras para aquele balde, o n�mero real de palavras individuais em cada balde, se o assunto da mensagem vai ser modificado quando ele for classificado para aquele balde, se as mensagens recebidas naquele balde devem ficar em quarentena, e uma tabela para escolher a cor usada para mostrar qualquer coisa relacionada �quele balde no centro de controle.
Bucket_StatisticsTableSummary           Esta tabela fornece tr�s conjuntos de estat�sticas sobre o desempenho geral do PopFile.  A primeira � a exatid�o da classifica��o, a segunda � quantas mensagens foram classificadas, e para quais baldes, e a terceira � quantas palavras existem em cada balde, e as suas porcentagens relativas.
Bucket_MaintenanceTableSummary          Esta tabela cont�m formul�rios que permitem que voc� crie, exclua ou renomeie baldes, e para procurar uma palavra em todos os baldes e ver as suas probabilidades relativas.
Bucket_AccuracyChartSummary             Esta tabela representa graficamente a exatid�o da classifica��o de mensagens.
Bucket_BarChartSummary                  Esta tabela representa graficamente a uma aloca��o porcentual para cada um dos diferentes baldes.  Ela � usada tanto para o n�mero de mensagens classificadas como para o n�mero total de palavras.
Bucket_LookupResultsSummary             Esta tabela mostra as probabilidades associadas com qualquer palavra espec�fica do corpus.  Para cada balde, ela mostra a freq��ncia com que cada palavra ocorre, a probabilidade de que ela ocorra naquele balde, e o efeito geral na pontua��o do balde se aquela palavra existir em uma mensagem.
Bucket_WordListTableSummary             Esta tabela fornece uma rela��o de todas as palavras para um balde espec�fico, organizada pela primeira letra comum para cada linha.
Magnet_MainTableSummary                 Esta tabela mostra a lista de �m�s que s�o usados para classificar automaticamente mensagens de acordo com regras fixas.  Cada linha mostra como o �m� est� definido, para qual balde ele foi concebido, e um bot�o para excluir aquele �m�.
Configuration_MainTableSummary          Esta tabela cont�m alguns formul�rios que permitem que voc� controle a configura��o do PopFile.
Configuration_InsertionTableSummary     Esta tabela cont�m bot�es para determinar se certas modifica��es s�o feitas no cabe�alho ou no assunto da mensagem antes que ela seja encaminhada para o programa cliente de mensagens.
Security_MainTableSummary               Esta tabela fornece conjuntos de controles que afetam a seguran�a da configura��o geral do PopFile, se ele deve procurar automaticamente por atualiza��es do programa, e se estat�sticas sobre o desempenho do PopFile devem ser enviadas ao banco de dados central do autor do programa para informa��o geral.
Advanced_MainTableSummary               Esta tabela fornece uma lista de palavras que o PopFile ignora quando classifica mensagens por causa da sua freq��ncia relativa nas mensagens em geral.  Elas s�o organizadas por linha de acordo com a primeira letra das palavras.

Imap_Bucket2Folder                      Email para o balde '<b>%s</b>' vai para a pasta
Imap_MapError                           Voc� n�o pode mapear mais de um balde para uma �nica pasta!
Imap_Server                             Nome do servidor IMAP:
Imap_ServerNameError                    Por favor informe o nome do servidor!
Imap_Port                               Porta do servidor IMAP:
Imap_PortError                          Por favor informe um n�mero de porta v�lido!
Imap_Login                              Conta de login IMAP:
Imap_LoginError                         Por favor informe um nome de usu�rio/login!
Imap_Password                           Senha para a conta IMAP:
Imap_PasswordError                      Por favor informe uma senha para o servidor!
Imap_Expunge                            Expurgar mensagens deletadas de pastas em observa��o.
Imap_Interval                           Intervalo de atualiza��o em segundos:
Imap_IntervalError                      Por favor informe um intervalo entre 10 e 3600 segundos.
Imap_Bytelimit                          Bytes por mensagem para usar para classifica��o. Informe 0 (Nulo) para usar a mensagem completa:
Imap_BytelimitError                     Por favor informe um n�mero.
Imap_RefreshFolders                     Atualizar a lista de pastas
Imap_Now                                agora!
Imap_UpdateError1                       N�o � poss�vel logar. Verifique seu nome de usu�rio e senha, por favor.
Imap_UpdateError2                       Falha na conex�o ao servidor. Por favor verifique o nome e porta do servidor e certifique-se que voc� est� online.
Imap_UpdateError3                       Por favor configure os detalhes da conex�o primeiro.
Imap_NoConnectionMessage                Por favor configure os detalhes da conex�o primeiro. Depois disto, mais op��es estar�o dispon�veis nesta p�gina.
Imap_WatchMore                          uma pasta para lista de pastas em observa��o
Imap_WatchedFolder                      Pasta em observa��o n�

Shutdown_Message                        O POPFile foi desligado

Help_Training                           Quando voc� usa o POPFile pela primeira vez, ele ainda n�o sabe nada e precisa de treinamento. O POPFile requer treinamento nas mensagens para cada balde, e o treinamento acontece quando voc� reclassifica para o balde correto uma mensagem que o POPFile classificou incorretamente. Voc� deve tamb�m configurar seu cliente de email para filtrar mensagens baseado na classifica��o do POPFile. Informa��o para configurar os filtros no seu cliente de email pode ser encontrado no <a href="http://getpopfile.org/docs/FAQ:EmailSorting">Projeto de Documenta��o do POPFile</a>.
Help_Bucket_Setup                       O POPFile requer pelo menos dois baldes al�m do pseudo-balde "unclassified". O que torna o POPFile �nico � que ele pode classificar email, mais do que isso, voc� pode ter qualquer n�mero de baldes. Uma configura��o simples poderia ser um balde "spam", "pessoal", e um balde "trabalho".
Help_No_More                            N�o mostre isto novamente
