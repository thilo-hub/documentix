# Copyright (c) 2001-2011 John Graham-Cumming
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
LanguageCode                            gr
LanguageCharset                         ISO-8859-7
LanguageDirection                       ltr

# This is used to get the appropriate subdirectory for the manual
ManualLanguage                          en

# Common words that are used on their own all over the interface
Apply                                   ��������
On                                     ������
Off                                     ��������
TurnOn                             ������������
TurnOff                             ������������
Add                                     ��������
Remove                                  ��������
Previous                                �����������
Next                                    �������
From                                    ����������
Subject                                 ����
Cc                                      ����. 
Classification                          ����������
Reclassify                              ���������������
Probability                             ����������
Scores                                  �����������
QuickMagnets                            �������� ��������
Undo                                    Undo
Close                                   ��������
Find                                    ������
Filter                                  ������
Yes                                     ���
No                                      ���
ChangeToYes                             ������ �� ���
ChangeToNo                              ������ �� ���
Bucket                                  ������
Magnet                                  ��������
Delete                                  ��������
Create                                  ����������
To                                      ����
Total                                   ������
Rename                                  �����������
Frequency                               ���������
Probability                             ����������
Score                                   ������
Lookup                                  �������
Word                                    ����
Count                             ����������
Update                                  ���������
Refresh                                 �����������

# The header and footer that appear on every UI page
Header_Title                            ������ ������� POPFile
Header_Shutdown                         �������� POPFile
Header_History                          ��������
Header_Buckets                          ������
Header_Configuration                    ��������
Header_Advanced                         ������������ ��������
Header_Security                         ��������
Header_Magnets                          ��������

Footer_HomePage                     ���������� POPFile
Footer_Manual                          ����������
Footer_Forums                          ����������
Footer_FeedMe                         ����������
Footer_RequestFeature           ������� ����������
Footer_MailingList                   ����������� mail

Configuration_Error1                    � ������������� ���������� ������ �� ����� ���� ����. 
Configuration_Error2                    ��  user interface port ������ �� ����� ������ 1 ��� 65535
Configuration_Error3                    �� POP3 listen port ������ �� ����� ������ 1 ��� 65535
Configuration_Error4                    �� ������� ������� ������ �� ����� ������ 1 ��� 1000
Configuration_Error5                    � ������� ������ ��� ������ ��������� ������ �� ����� ������ 1 ��� 366
Configuration_Error6                    � ���������� TCP timeout ������ �� ����� ������ 10 ��� 1800
Configuration_Error7                    � ���������� XML RPC listen port ������ �� ����� ������ 1 ��� 65535
Configuration_POP3Port                  POP3 listen port
Configuration_POP3Update                � ���������� POP3 port ������ �� %s; �� ������� �� ������ ������� ���� ������� �������� ��� POPFile
Configuration_XMLRPCUpdate              � ���������� XML-RPC port ������ �� %s;  �� ������� �� ������ ������� ���� ������� �������� ��� POPFile
Configuration_XMLRPCPort                XML-RPC listen port
Configuration_SMTPPort                  SMTP listen port
Configuration_SMTPUpdate                � ���������� SMTP port ������ �� %s;  �� ������� �� ������ ������� ���� ������� �������� ��� POPFile
Configuration_NNTPPort                  NNTP listen port
Configuration_NNTPUpdate                � ���������� NNTP port ������ �� %s;  �� ������� �� ������ ������� ���� ������� �������� ��� POPFile
Configuration_POP3Separator             POP3 host:port:���������� �����������
Configuration_NNTPSeparator             NNTP host:port:���������� �����������
Configuration_POP3SepUpdate             ������ ��������� ����������� POP3 �� %s
Configuration_NNTPSepUpdate             ������ ��������� ����������� NNTP �� %s
Configuration_UI                        Web port ���������� �������
Configuration_UIUpdate                  Updated user interface web port to %s; this change will not take affect until you restart POPFile
Configuration_History                   ������� ��������� ��� ������
Configuration_HistoryUpdate             ������ ������� ��������� ��� ������ �� %s
Configuration_Days                      ������� ������ ��� ���������� �� ��������
Configuration_DaysUpdate                ������ ������� ������ ��� ���������� �� �������� �� %s
Configuration_UserInterface             ��������� �������
Configuration_Skins                     ��������
Configuration_SkinsChoose               ������� ���������
Configuration_Language                  ������
Configuration_LanguageChoose            ������� �������
Configuration_ListenPorts               �������� ������������
Configuration_HistoryView               ��������
Configuration_TCPTimeout                Connection Timeout
Configuration_TCPTimeoutSecs            Connection timeout �� ������������
Configuration_TCPTimeoutUpdate          ������  connection timeout �� %s
Configuration_ClassificationInsertion   �������� �������� �� ��������
Configuration_SubjectLine               ������ ������� ���������
Configuration_XTCInsertion              X-Text-Classification Header
Configuration_XPLInsertion              X-POPFile-Link Header
Configuration_Logging                   ���������� ���������
Configuration_None                      ������
Configuration_ToScreen                  ���� �����
Configuration_ToFile                    �� ������
Configuration_ToScreenFile              ���� ����� ��� �� ������
Configuration_LoggerOutput              �������� ����������� ���������
Configuration_GeneralSkins              ����������
Configuration_SmallSkins                 ������ ����������
Configuration_TinySkins                 ��� ������ ����������
Configuration_CurrentLogFile            &lt;current log file&gt;

Advanced_Error1                         '%s' ����� ��� ���� ������������ ������
Advanced_Error2                         �� ������������ ������ ������� �� ���������������� ���� �������������� ������ , ., _, -, � @ ����������
Advanced_Error3                         '%s' ���������� ���� ������������ ������
Advanced_Error4                         '%s' ��� ������ ���� ������������ ������
Advanced_Error5                         '%s' ���������� ��� ��� ������������ ������
Advanced_StopWords                      ������ ��� ����������� 
Advanced_Message1                       �� POPFile ������� ��� ��������� ����� ������������� ������ :
Advanced_AddWord                        �������� �����
Advanced_RemoveWord                     �������� �����

History_Filter                          &nbsp;(����������� ����� ������ <font color="%s">%s</font>)
History_FilterBy                        ����������� �� �����
History_Search                          &nbsp;(��������� ��� ���������/���� %s)
History_Title                           �������� ��������
History_Jump                            �������� ���
History_ShowAll                         �������� ����
History_ShouldBe                        �� ����������� ��
History_NoFrom                          ��� ���� ���������
History_NoSubject                       ��� ������� ����
History_ClassifyAs                      �� ����������� ���
History_MagnetUsed                      �������� �� �����
History_MagnetBecause                   <b>�������� �� �����</b><p>���� ����������� �� <font color="%s">%s</font> ���� ������� %s </p>
History_ChangedTo                       ������ �� <font color="%s">%s
History_Already                         ���� ��� ���������������� �� <font color="%s">%s</font>
History_RemoveAll                       �������� ����
History_RemovePage                     �������� �������
History_Remove                          ��� �� ���������� �������� ��� ��������� �������
History_SearchMessage                   ��������� ���������/����
History_NoMessages                      ��� �������� ��������
History_ShowMagnet                      ������������
History_ShowNoMagnet                    �� ������������
History_Magnet                          &nbsp;(�������� ���� ������������� ���������)
History_NoMagnet                        &nbsp;(�������� ���� �� ������������� ���������)
History_ResetSearch                     ���������

Password_Title                          �������
Password_Enter                          ������ �������
Password_Go                             ����������!
Password_Error1                         ����� �������

Security_Error1                         ��  port ������ �� ����� ���� ������� ������ 1 ��� 65535
Security_Stealth                        ���������� ���������/���������� Server
Security_NoStealthMode                  ��� ( ���������� ��������� )
Security_ExplainStats                   (�� ���� ��� ������� ������ �� POPFile ������� ���� ����� ��� ��������� ����� ����������� �� ��� ��������� ��� getpopfile.org: bc (������ ������� ��� ���������������� ), mc (������ ������������� ���������) and ec (������ ����� �����������).  ���� ��������������� ��� ���������������� ��� �� ���������� ����������� ��� �� ��� �� ������� ������������� �� POPFile ���� ��� ���� �������������� ���� ��������s.  �� ������ ��������� �� ��� ��������� ����������; ��� �������� ����������� ������ ��� ����������� ��� ��� ����������� ����������� IP.)
Security_ExplainUpdate                  (�� ���� ��� ������� ������ �� POPFile ������� ���� ����� ��� ��������� ����� ����������� �� ��� ��������� ��� getpopfile.org:: ma (��� ����� ������ ������� ��� �� ����� POPFile), mi (��� ������������ ������ ������� ��� �� ����� POPFile) ��� bn (���  ������ ������� ��� �� ����� POPFile).  �� POPFile �������� ��� �������� �� ��� ����� �������� ��� ����������� ���� ��� ����� ��� �������, ��� ��� ��������� ��� ������� ��� ����������� ������.  �� ������ ��������� �� ��� ��������� ����������; ��� �������� ����������� ������ ��� ����������� ��� ��� ����������� ����������� IP.)
Security_PasswordTitle                  ������� ���������� ������
Security_Password                       �������
Security_PasswordUpdate                 �� ������� ������ ��  %s
Security_AUTHTitle                      Remote Servers
Security_SecureServer                   POP3 SPA/AUTH server
Security_SecureServerUpdate             � ���������� POP3 SPA/AUTH secure server ������ �� %s; �� ������� �� ������ ������� ���� ������� �������� ��� POPFile
Security_SecurePort                     POP3 SPA/AUTH port
Security_SecurePortUpdate               � ���������� POP3 SPA/AUTH port  ������ �� %s; �� ������� �� ������ ������� ���� ������� �������� ��� POPFile
Security_SMTPServer                     SMTP chain server
Security_SMTPServerUpdate               � ���������� SMTP chain server ������ �� %s; �� ������� �� ������ ������� ���� ������� �������� ��� POPFile
Security_SMTPPort                       SMTP chain port
Security_SMTPPortUpdate                 � ���������� SMTP chain port ������ �� %s; �� ������� �� ������ ������� ���� ������� �������� ��� POPFile
Security_POP3                           �� �������� ��������� ��������� POP3 ��� �/� ��� ������ (���������� ������������ ��� POPFile )
Security_SMTP                           �� �������� ��������� ��������� SMTP ��� �/� ��� ������ (���������� ������������ ��� POPFile )
Security_NNTP                           �� �������� ��������� ��������� NNTP ��� �/� ��� ������ (���������� ������������ ��� POPFile )
Security_UI                             �� �������� ��������� ��������� HTTP ��� �/� ��� ������ (���������� ������������ ��� POPFile )
Security_XMLRPC                         �� �������� ��������� ��������� XML-RPC ��� �/� ��� ������ (���������� ������������ ��� POPFile )
Security_UpdateTitle                    ��������� ������� ��� ������������ ��������
Security_Update                         ����������� ������� ��� ������������ �������� ���  POPFile
Security_StatsTitle                     �������� �����������
Security_Stats                          ���������� �������� �����������

Magnet_Error1                           � �������� '%s' ������� ��� ��� ������ '%s'
Magnet_Error2                           � ���� �������� '%s' ����� �� �������� �� ��� ��� ��������� '%s' ��� ������ '%s' ��� ���� �� �������� �� ����������� ������������.  � ���� �������� ��� ����������..
Magnet_Error3                           ���������� ���� ������� '%s' ��� ������ '%s'
Magnet_CurrentMagnets                   ���������� ��������
Magnet_Message1                         �� ��������� �������� ����� ���������� �� �������� ��� ��� �������������� ������ :.
Magnet_CreateNew                        ���������� ���� �������
Magnet_Explanation                      ����� �� ����� ������� ����� ����������: <ul><li><b>��� ��������� � �����:</b> �.�.: john@company.com ��� ������������ ���������s, <br />company.com ��� ���� ��� ����������� ��� ���������� �� company.com, <br />John Doe ��� ������������ �����, John ��� ����� �� ����� ����� John</li><li><b>����/����. ��������� � �����:</b> ����� ��� ��������� ���� ����� �� ����� ����/ ����.:</li> <li><b>���� :</b> �.�.: hello ��� �� ������������ ��� �� �������� ��� ��������� ��� ���� hello ��� ����</li></ul>
Magnet_MagnetType                      ����� ��������
Magnet_Value                            ����
Magnet_Always                           ����� ������������ ��� ������
Magnet_Jump                             �������� ��� 

Bucket_Error1                           �� ������� ��� ������� ������� �� ��������� ���� �� ���� ������� ��������  a ��� z, ���� �������� 0 ��� 9,  ��� ���� ����������  - ��� _
Bucket_Error2                           ������  %s ������� ���
Bucket_Error3                           ������������� ������ �� ����� %s
Bucket_Error4                           ����������� �������� �� ��� ���� ����
Bucket_Error5                           �� ������ %s ������������� �� %s
Bucket_Error6                           ����������� �� ������ %s
Bucket_Title                            ��������
Bucket_BucketName                       ������
Bucket_WordCount                        ������ ������
Bucket_WordCounts                       ���������� ������
Bucket_UniqueWords                      ��������� ������
Bucket_SubjectModification              ������ ������� ���������
Bucket_ChangeColor                      ������ ��������
Bucket_NotEnoughData                    �������� ��������
Bucket_ClassificationAccuracy           �������� �����������
Bucket_EmailsClassified                 ������������ ��������
Bucket_EmailsClassifiedUpper            ������������ ��������
Bucket_ClassificationErrors             �������� �����������
Bucket_Accuracy                         �������� �����������
Bucket_ClassificationCount              �����. ������������
Bucket_ClassificationFP                 ����� ������
Bucket_ClassificationFN                 ����� ��������
Bucket_ResetStatistics                  ���������� �����������
Bucket_LastReset                        ���������� ����������
Bucket_CurrentColor                     ������ ����� %s  ����� %s
Bucket_SetColorTo                       ������� ��������  %s �� %s
Bucket_Maintenance                      ��������� �������
Bucket_CreateBucket                     ���������� ������� �� �����
Bucket_DeleteBucket                     �������� ������� �� �����
Bucket_RenameBucket                     ����������� ������� �� �����
Bucket_Lookup                           ������
Bucket_LookupMessage                    ������� ������ �� ������
Bucket_LookupMessage2                   ������������ ������� ������ 
Bucket_LookupMostLikely                 <b>%s</b> ����� ��� ������ �� ������ ��� <font color="%s">%s</font>
Bucket_DoesNotAppear                    <p><b>%s</b> ��� ������ �� ������ ��� �� ������
Bucket_DisabledGlobally                 ������� ���������������� 
Bucket_To                               ��
Bucket_Quarantine                       ���������

SingleBucket_Title                      ������������ ��� ������� %s
SingleBucket_WordCount                  ������� ������ �������
SingleBucket_TotalWordCount             ��������� ���������� ������
SingleBucket_Percentage                 ������� ��� �������
SingleBucket_WordTable                  ������� ������ ��� %s
SingleBucket_Message1                   ����� ���� ���� �� ��� ������ ��� �� ����� ��� ������ ��� �������� ��� ����.  ����� ���� �� ��� ���� ��� �� ����� ��� ����������� �� ������ �� ����������� ������..
SingleBucket_Unique                     %s ���������
SingleBucket_ClearBucket                �������� ���� ��� ������

Session_Title                           � �������� ��� POPFile ���� �����
Session_Error                           � ������� �������� POPFile ���� �����.  ���� ����� �� ����� ���������� ��� ������������� ��� POPFile ����� �� ��������� ��������� ����������� ��� ��������� �������.  ����������� ����� ���� �� ������ ��� ��� ����� ��������� ��� �� �������������� ��� ����������� �� �� POPFile.

View_Title                              �������� ����������� ���������

Header_MenuSummary                      This table is the navigation menu which allows access to each of the different pages of the control center.
History_MainTableSummary                This table shows the sender and subject of recently received messages and allows them to be reviewed and reclassified.  Clicking on the subject line will show the full message text, along with information about why it was classified as it was.  The 'Should be' column allows you to specify which bucket the message belongs in, or to undo that change.  The 'Delete' column allows you to delete specific messages from the history if you don't need them anymore.
History_OpenMessageSummary              This table contains the full text of a message message, with the words that are used for classification highlighted according to the bucket that was most relevant for each.
Bucket_MainTableSummary                 This table provides an overview of the classification buckets.  Each row shows the bucket name, the word count total for that bucket, the actual number of individual words in each bucket, whether the message's subject line will be modified when it gets classified to that bucket, whether to quarantine the messages received in that bucket, and a table to pick the color used in displaying anything related to that bucket in the control center.
Bucket_StatisticsTableSummary           This table provides three sets of statistics on the overall performance of POPFile.  The first is how accurate its classification is, the second is how many messages have been classified, and to which buckets, and the third is how many words are in each bucket, and what their relative percentages are.
Bucket_MaintenanceTableSummary          This table contains forms that allow you to create, delete or rename buckets, and to lookup a word in all of the buckets to see its relative probabilities.
Bucket_AccuracyChartSummary             This table graphically represents the accuracy of the message classification.
Bucket_BarChartSummary                  This table graphically represents a percentage allocation for each of the different buckets.  It is used for both number of messages classified, and total word counts.
Bucket_LookupResultsSummary             This table shows the probabilities associated with any given word of the corpus.  For each bucket, it shows the frequency that that word occurs, the probability that it will occur in that bucket, and the overall effect on the score of the bucket if that word exists in a message.
Bucket_WordListTableSummary             This table provides a listing of all the words for a particular bucket, organized by common first letter for each row.
Magnet_MainTableSummary                 This table shows the list of magnets that are used to automatically classify message according to fixed rules.  Each row shows how the magnet is defined, what bucket it is intended for, and a button to delete the magnet.
Configuration_MainTableSummary          This table contains a number of forms to allow you to control the configuration of POPFile.
Configuration_InsertionTableSummary     This table contains buttons that determine whether or not certain modifications are made to the headers or subject line of the message before it is passed on to the message client.
Security_MainTableSummary               This table provides sets of controls that affect the security of the overall configuration of POPFile, whether it should automatically check for updates to the program, and whether statistics about POPFile's performance should be sent to the central datastore of the program's author for general information.
Advanced_MainTableSummary               This table provides a list of words that POPFile ignores when classifying message due to their relative frequency in message in general.  They are organized per row according to the first letter of the words.

