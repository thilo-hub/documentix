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
#   POPFile 1.0.0 Traditional Chinese Translation
#   Created By Jedi Lin, 2004/09/19
#   Modified By Jedi Lin, 2007/12/25

# Identify the language and character set used for the interface
LanguageCode                            tw
LanguageCharset                         BIG5
LanguageDirection                       ltr

# This is used to get the appropriate subdirectory for the manual
ManualLanguage                          zh-tw

# This is where to find the FAQ on the Wiki
FAQLink                                 FAQ

# Common words that are used on their own all over the interface
Apply                                   �M��
ApplyChanges                            �M���ܧ�
On                                      �}
Off                                     ��
TurnOn                                  ���}
TurnOff                                 ���W
Add                                     �[�J
Remove                                  ����
Previous                                �e�@��
Next                                    �U�@��
From                                    �H���
Subject                                 �D��
Cc                                      �ƥ�
Classification                          �l��
Reclassify                              ���s����
Probability                             �i���
Scores                                  ����
QuickMagnets                            �ֳt�l�K
Undo                                    �٭�
Close                                   ����
Find                                    �M��
Filter                                  �L�o��
Yes                                     �O
No                                      �_
ChangeToYes                             �令�O
ChangeToNo                              �令�_
Bucket                                  �l��
Magnet                                  �l�K
Delete                                  �R��
Create                                  �إ�
To                                      ����H
Total                                   ����
Rename                                  ��W
Frequency                               �W�v
Probability                             �i���
Score                                   ����
Lookup                                  �d��
Word                                    �r��
Count                                   �p��
Update                                  ��s
Refresh                                 ���s��z
FAQ                                     �`���ݵ���
ID                                      ID
Date                                    ���
Arrived                                 ����ɶ�
Size                                    �j�p

# This is a regular expression pattern that is used to convert
# a number into a friendly looking number (for the US and UK this
# means comma separated at the thousands)

Locale_Thousands                       ,
Locale_Decimal                         .

# The Locale_Date uses the format strings in Perl's Date::Format
# module to set the date format for the UI.  There are two possible
# ways to specify it.
#
# <format>            Just one simple format used for all dates
# <<format> | <format> The first format is used for dates less than
#                     7 days from now, the second for all other dates

Locale_Date                            %a %m/%d %T %z | %A %Y/%m/%d %T %z

# The header and footer that appear on every UI page
Header_Title                            POPFile �����
Header_Shutdown                         ���� POPFile
Header_History                          ���v
Header_Buckets                          �l��
Header_Configuration                    �պA
Header_Advanced                         �i��
Header_Security                         �w��
Header_Magnets                          �l�K

Footer_HomePage                         POPFile ����
Footer_Manual                           ��U
Footer_Forums                           �Q�װ�
Footer_FeedMe                           ���U
Footer_RequestFeature                   �\��ШD
Footer_MailingList                      �l�����D
Footer_Wiki                             ���

Configuration_Error1                    ���j�Ŭ��O��@���r��
Configuration_Error2                    �ϥΪ̤������s����@�w�n���� 1 �M 65535 ����
Configuration_Error3                    POP3 ��ť�s����@�w�n���� 1 �M 65535 ����
Configuration_Error4                    �����j�p�@�w�n���� 1 �M 1000 ����
Configuration_Error5                    ���v�حn�O�d����Ƥ@�w�n���� 1 �M 366 ����
Configuration_Error6                    TCP �O�ɭȤ@�w�n���� 10 �M 1800 ����
Configuration_Error7                    XML RPC ��ť�s����@�w�n���� 1 �M 65535 ����
Configuration_Error8                    SOCKS V �N�z���A���s����@�w�n���� 1 �M 65535 ����
Configuration_POP3Port                  POP3 ��ť�s����
Configuration_POP3Update                POP3 �s����w��s�� %s; �o����ʦb�p���s�Ұ� POPFile �e�����|�ͮ�
Configuration_XMLRPCUpdate              XML-RPC �s����w��s�� %s; �o����ʦb�p���s�Ұ� POPFile �e�����|�ͮ�
Configuration_XMLRPCPort                XML-RPC ��ť�s����
Configuration_SMTPPort                  SMTP ��ť�s����
Configuration_SMTPUpdate                SMTP �s����w��s�� %s; �o����ʦb�p���s�Ұ� POPFile �e�����|�ͮ�
Configuration_NNTPPort                  NNTP ��ť�s����
Configuration_NNTPUpdate                NNTP �s����w��s�� %s; �o����ʦb�p���s�Ұ� POPFile �e�����|�ͮ�
Configuration_POPFork                   ���\���ƪ� POP3 �s�u
Configuration_SMTPFork                  ���\���ƪ� SMTP �s�u
Configuration_NNTPFork                  ���\���ƪ� NNTP �s�u
Configuration_POP3Separator             POP3 �D��:�s����:�ϥΪ� ���j��
Configuration_NNTPSeparator             NNTP �D��:�s����:�ϥΪ� ���j��
Configuration_POP3SepUpdate             POP3 �����j�Ťw��s�� %s
Configuration_NNTPSepUpdate             NNTP �����j�Ťw��s�� %s
Configuration_UI                        �ϥΪ̤��������s����
Configuration_UIUpdate                  �ϥΪ̤��������s����w��s�� %s; �o����ʦb�p���s�Ұ� POPFile �e�����|�ͮ�
Configuration_History                   �C�@���ҭn�C�X���l��T���ƶq
Configuration_HistoryUpdate             �C�@���ҭn�C�X���l��T���ƶq�w��s�� %s
Configuration_Days                      ���v�ةҭn�O�d���Ѽ�
Configuration_DaysUpdate                ���v�ةҭn�O�d���ѼƤw��s�� %s
Configuration_UserInterface             �ϥΪ̤���
Configuration_Skins                     �~�[�˦�
Configuration_SkinsChoose               ��ܥ~�[�˦�
Configuration_Language                  �y��
Configuration_LanguageChoose            ��ܻy��
Configuration_ListenPorts               �Ҳտﶵ
Configuration_HistoryView               ���v�˵�
Configuration_TCPTimeout                �s�u�O��
Configuration_TCPTimeoutSecs            �s�u�O�ɬ���
Configuration_TCPTimeoutUpdate          �s�u�O�ɬ��Ƥw��s�� %s
Configuration_ClassificationInsertion   ���J�l��T����r
Configuration_SubjectLine               �ܧ�D���C
Configuration_XTCInsertion              �b���Y���J<br>X-Text-Classification
Configuration_XPLInsertion              �b���Y���J<br>X-POPFile-Link
Configuration_Logging                   ��x
Configuration_None                      �L
Configuration_ToScreen                  ��X�ܿù� (Console)
Configuration_ToFile                    ��X���ɮ�
Configuration_ToScreenFile              ��X�ܿù����ɮ�
Configuration_LoggerOutput              ��x��X�覡
Configuration_GeneralSkins              �~�[�˦�
Configuration_SmallSkins                �p���~�[�˦�
Configuration_TinySkins                 �L���~�[�˦�
Configuration_CurrentLogFile            &lt;�˵��ثe����x��&gt;
Configuration_SOCKSServer               SOCKS V �N�z���A���D��
Configuration_SOCKSPort                 SOCKS V �N�z���A���s����
Configuration_SOCKSPortUpdate           SOCKS V �N�z���A���s����w��s�� %s
Configuration_SOCKSServerUpdate         SOCKS V �N�z���A���D���w��s�� %s
Configuration_Fields                    ���v���

Advanced_Error1                         '%s' �w�g�b�����r���M���ؤF
Advanced_Error2                         �n�Q�������r���ȯ�]�t�r���Ʀr, ., _, -, �� @ �r��
Advanced_Error3                         '%s' �w�Q�[�J�����r���M���ؤF
Advanced_Error4                         '%s' �ä��b�����r���M����
Advanced_Error5                         '%s' �w�q�����r���M���سQ�����F
Advanced_StopWords                      �Q�������r��
Advanced_Message1                       POPFile �|�����U�C�o�Ǳ`�Ϊ��r��:
Advanced_AddWord                        �[�J�r��
Advanced_RemoveWord                     �����r��
Advanced_AllParameters                  �Ҧ��� POPFile �Ѽ�
Advanced_Parameter                      �Ѽ�
Advanced_Value                          ��
Advanced_Warning                        �o�O���㪺 POPFile �ѼƲM��.  ��A�X�i���ϥΪ�: �p�i�H�ܧ����ѼƭȨë��U ��s; ���L�S���������|�ˬd�o�ǰѼƭȪ����ĩ�.  �H������ܪ����ت��ܤw�g�q�w�]�ȳQ�[�H�ܧ�F.  ��Ժɪ��ﶵ��T�Ш� <a href="http://getpopfile.org/docs/OptionReference">OptionReference</a>.
Advanced_ConfigFile                     �պA��:

History_Filter                          &nbsp;(����� <font color="%s">%s</font> �l��)
History_FilterBy                        �L�o����
History_Search                          &nbsp;(���H���/�D���ӷj�M %s)
History_Title                           �̪񪺶l��T��
History_Jump                            ����o�@��
History_ShowAll                         �������
History_ShouldBe                        ���ӭn�O
History_NoFrom                          �S���H��̦C
History_NoSubject                       �S���D���C
History_ClassifyAs                      ������
History_MagnetUsed                      �ϥΤF�l�K
History_MagnetBecause                   <b>�ϥΤF�l�K</b><p>�Q������ <font color="%s">%s</font> ����]�O %s �l�K</p>
History_ChangedTo                       �w�ܧ� <font color="%s">%s</font>
History_Already                         ���s������ <font color="%s">%s</font>
History_RemoveAll                       ��������
History_RemovePage                      ��������
History_RemoveChecked                   �����Q�ֿ諸
History_Remove                          �����������v�ت�����
History_SearchMessage                   �j�M�H���/�D��
History_NoMessages                      �S���l��T��
History_ShowMagnet                      �ΤF�l�K
History_Negate_Search                   �t�V�j�M/�L�o
History_Magnet                          &nbsp;(����ܥѧl�K�Ҥ������l��T��)
History_NoMagnet                        &nbsp;(����ܤ��O�ѧl�K�Ҥ������l��T��)
History_ResetSearch                     ���]
History_ChangedClass                    �{�b�Q������
History_Purge                           �Y����
History_Increase                        �W�[
History_Decrease                        ���
History_Column_Characters               �ܧ�H���, �����, �ƥ��M�D����쪺�e��
History_Automatic                       �۰ʤ�
History_Reclassified                    �w���s����
History_Size_Bytes                      %d&nbsp;B
History_Size_KiloBytes                  %.1f&nbsp;KB
History_Size_MegaBytes                  %.1f&nbsp;MB

Password_Title                          �K�X
Password_Enter                          ��J�K�X
Password_Go                             ��!
Password_Error1                         �����T���K�X

Security_Error1                         �s����@�w�n���� 1 �M 65535 ����
Security_Stealth                        ���������Ҧ�/���A���@�~
Security_NoStealthMode                  �_ (���������Ҧ�)
Security_StealthMode                    (���������Ҧ�)
Security_ExplainStats                   (�o�ӿﶵ�}�ҫ�, POPFile �C�ѳ��|�ǰe�@���U�C�T�ӼƭȨ� getpopfile.org ���@�Ӹ}��: bc (�p���l���ƶq), mc (�Q POPFile �����L���l��T���`��) �M ec (�������~���`��).  �o�Ǽƭȷ|�Q�x�s��@���ɮ���, �M��|�Q�ڥΨӵo�G�@������H�̨ϥ� POPFile �����p��䦨�Ī��έp���.  �ڪ��������A���|�O�d�䥻������x�ɬ� 5 ��, �M��N�|�[�H�R��; �ڤ��|�x�s����έp�P��W IP �a�}�������p�ʰ_��.)
Security_ExplainUpdate                  (�o�ӿﶵ�}�ҫ�, POPFile �C�ѳ��|�ǰe�@���U�C�T�ӼƭȨ� getpopfile.org ���@�Ӹ}��: ma (�p�� POPFile ���D�n�����s��), mi (�p�� POPFile �����n�����s��) �M bn (�p�� POPFile ���ظ�).  �s�����X��, POPFile �|����@���ϧΦ^��, �åB��ܦb�e������.  �ڪ��������A���|�O�d�䥻������x�ɬ� 5 ��, �M��N�|�[�H�R��; �ڤ��|�x�s�����s�ˬd�P��W IP �a�}�������p�ʰ_��.)
Security_PasswordTitle                  �ϥΪ̤����K�X
Security_Password                       �K�X
Security_PasswordUpdate                 �K�X�w��s
Security_AUTHTitle                      ���ݦ��A��
Security_SecureServer                   ���� POP3 ���A�� (SPA/AUTH �ά�z���N�z���A��)
Security_SecureServerUpdate             ���� POP3 ���A���w��s�� %s
Security_SecurePort                     ���� POP3 �s���� (SPA/AUTH �ά�z���N�z���A��)
Security_SecurePortUpdate               ���� POP3 �s����w��s�� %s
Security_SMTPServer                     SMTP �s����A��
Security_SMTPServerUpdate               SMTP �s����A���w��s�� %s; �o����ʦb�p���s�Ұ� POPFile �e�����|�ͮ�
Security_SMTPPort                       SMTP �s��s����
Security_SMTPPortUpdate                 SMTP �s��s����w��s�� %s; �o����ʦb�p���s�Ұ� POPFile �e�����|�ͮ�
Security_POP3                           �����Ӧۻ��ݾ����� POP3 �s�u (�ݭn���s�Ұ� POPFile)
Security_SMTP                           �����Ӧۻ��ݾ����� SMTP �s�u (�ݭn���s�Ұ� POPFile)
Security_NNTP                           �����Ӧۻ��ݾ����� NNTP �s�u (�ݭn���s�Ұ� POPFile)
Security_UI                             �����Ӧۻ��ݾ����� HTTP (�ϥΪ̤���) �s�u (�ݭn���s�Ұ� POPFile)
Security_XMLRPC                         �����Ӧۻ��ݾ����� XML-RPC �s�u (�ݭn���s�Ұ� POPFile)
Security_UpdateTitle                    �۰ʧ�s�ˬd
Security_Update                         �C���ˬd POPFile �O�_����s
Security_StatsTitle                     �^���έp���
Security_Stats                          �C��e�X�έp���

Magnet_Error1                           '%s' �l�K�w�g�s�b�� '%s' �l���ؤF
Magnet_Error2                           �s�� '%s' �l�K��J���� '%s' �l�K�_�F�Ĭ�, �i��|�ް_ '%s' �l�������[�����G.  �s���l�K���|�Q�[�i�h.
Magnet_Error3                           �إ߷s���l�K '%s' �� '%s' �l����
Magnet_CurrentMagnets                   �{�Ϊ��l�K
Magnet_Message1                         �U�C���l�K�|���H���`�O�Q������S�w���l����.
Magnet_CreateNew                        �إ߷s���l�K
Magnet_Explanation                      ���o�����O���l�K�i�H��: <ul><li><b>�H��̦a�}�ΦW�r:</b> �|�Ҩӻ�: john@company.com �N��|�k�X�S�w���a�}, <br />company.com �|�k�X�����q company.com �H�X�Ӫ��H, <br />John Doe �|�k�X�S�w���H, John �|�k�X�Ҧ��� Johns</li><li><b>�����/�ƥ��a�}�ΦW��:</b> �N��H��̤@��: ���O�l�K��|�w��l��T���ت� To:/Cc: �a�}�ͮ�</li> <li><b>�D���r��:</b> �Ҧp: hello �|�k�X�Ҧ��D���ئ� hello ���l��T��</li></ul>
Magnet_MagnetType                       �l�K���O
Magnet_Value                            ��
Magnet_Always                           �`�O����l��
Magnet_Jump                             ����l�K����

Bucket_Error1                           �l���W�٬��t���p�g a �� z ���r��, 0 �� 9 ���Ʀr, �[�W - �M _
Bucket_Error2                           �w�g���W�� %s ���l���F
Bucket_Error3                           �w�g�إߤF�W�� %s ���l��
Bucket_Error4                           �п�J�D�ťժ��r��
Bucket_Error5                           �w�g�� %s �l����W�� %s �F
Bucket_Error6                           �w�g�R���F %s �l���F
Bucket_Title                            �l���պA
Bucket_BucketName                       �l���W��
Bucket_WordCount                        �r���p��
Bucket_WordCounts                       �r���ƥزέp
Bucket_UniqueWords                      �W�S��<br>�r����
Bucket_SubjectModification              �ק�D�����Y
Bucket_ChangeColor                      �l���C��
Bucket_NotEnoughData                    ��Ƥ���
Bucket_ClassificationAccuracy           �����ǽT��
Bucket_EmailsClassified                 �w�������l��T���ƶq
Bucket_EmailsClassifiedUpper            �l��T���������G
Bucket_ClassificationErrors             �������~
Bucket_Accuracy                         �ǽT��
Bucket_ClassificationCount              �����p��
Bucket_ClassificationFP                 �����ʤ���
Bucket_ClassificationFN                 �����ʤ���
Bucket_ResetStatistics                  ���]�έp���
Bucket_LastReset                        �e�����]��
Bucket_CurrentColor                     %s �{�Ϊ��C�⬰ %s
Bucket_SetColorTo                       �]�w %s ���C�⬰ %s
Bucket_Maintenance                      ���@
Bucket_CreateBucket                     �γo�ӦW�r�إ߶l��
Bucket_DeleteBucket                     �R�����W�٪��l��
Bucket_RenameBucket                     ��惡�W�٪��l��
Bucket_Lookup                           �d��
Bucket_LookupMessage                    �b�l���جd��r��
Bucket_LookupMessage2                   �d�䦹�r�������G
Bucket_LookupMostLikely                 <b>%s</b> �̹��O�b <font color="%s">%s</font> �|�X�{�����
Bucket_DoesNotAppear                    <p><b>%s</b> �å��X�{�����l����
Bucket_DisabledGlobally                 �w���찱�Ϊ�
Bucket_To                               ��
Bucket_Quarantine                       �j���l��

SingleBucket_Title                      %s ���ԲӸ��
SingleBucket_WordCount                  �l���r���p��
SingleBucket_TotalWordCount             �������r���p��
SingleBucket_Percentage                 ���������ʤ���
SingleBucket_WordTable                  %s ���r����
SingleBucket_Message1                   ���U�����ت��r���ӬݬݩҦ��H�Ӧr���}�Y���r��.  ���U����r���N�i�H�d�䥦�b�Ҧ��l���ت��i���.
SingleBucket_Unique                     %s �W����
SingleBucket_ClearBucket                �����Ҧ����r��

Session_Title                           POPFile ���q�ɴ��w�O��
Session_Error                           �p�� POPFile ���q�ɴ��w�g�O���F.  �o�i��O�]���p�Ұʨð���F POPFile ���o�O�������s�����}�ҩҭP.  �Ы��U�C���쵲���@���~��ϥ� POPFile.

View_Title                              ��@�l��T���˵�
View_ShowFrequencies                    ��ܦr���W�v
View_ShowProbabilities                  ��ܦr���i���
View_ShowScores                         ��ܦr���o���ΧP�w�Ϫ�
View_WordMatrix                         �r���x�}
View_WordProbabilities                  ���b��ܦr���i���
View_WordFrequencies                    ���b��ܦr���W�v
View_WordScores                         ���b��ܦr���o��
View_Chart                              �P�w�Ϫ�
View_DownloadMessage                    �U���l��T��

Windows_TrayIcon                        �O�_�n�b Windows ���t�α`�n�C��� POPFile �ϥ�?
Windows_Console                         �O�_�n�b�R�O�C�����ذ��� POPFile?
Windows_NextTime                        <p><font color="red">�o����ʦb�p���s�Ұ� POPFile �e�����|�ͮ�</font>

Header_MenuSummary                      �o�Ӫ���O���������, �����p�s��������ؤ��P���C�@�ӭ���.
History_MainTableSummary                �o������C�X�F�̪񦬨쪺�l��T�����H��̤ΥD��, �p�]��b�����s�[�H�˵��í��s�����o�Ƕl��T��.  ���@�U�D���C�N�|��ܥX���㪺�l��T����r, �H�Φo�̬���|�Q�p����������T.  �p�i�H�b '���ӭn�O' �����w�l��T�����k�ݪ��l��, �Ϊ��٭�o���ܧ�.  �p�G���S�w���l��T���A�]���ݭn�F, �p�]�i�H�� '�R��' ���ӱq���v�إ[�H�R��.
History_OpenMessageSummary              �o�Ӫ���t���Y�Ӷl��T��������, �䤤�Q���G�׼Хܪ��r���O�Q�ΨӤ�����, �̾ڪ��O�o�̸򨺭Ӷl���̦����p.
Bucket_MainTableSummary                 �o�Ӫ��洣�ѤF�����l�������p.  �C�@�C���|��ܥX�l���W��, �Ӷl���ت��r���`��, �C�Ӷl���ع�ڪ���W�r���ƶq, �l��T�����D���C�O�_�|�b�Q������Ӷl���ɤ@�ֳQ�ק�, �O�_�n�j���Q���i�Ӷl���ت��l��T��, �H�Τ@�����p�D���C�⪺����, �o���C��|�b���������ܩ�����Ӷl���������a��.
Bucket_StatisticsTableSummary           �o�Ӫ��洣�ѤF�T�ո� POPFile ����į঳�����έp���.  �Ĥ@�լO������ǽT�צp��, �ĤG�լO�@���h�ֶl��T���Q�[�H�����쨺�Ӷl����, �ĤT�լO�C�Ӷl���ئ��h�֦r���Ψ����p�ʤ���.
Bucket_MaintenanceTableSummary          �o�Ӫ���t���@�Ӫ���, ���p����إ�, �R��, �έ��s�R�W�Y�Ӷl��, �]�i�H�b�Ҧ����l���جd��Y�Ӧr��, �ݬݨ����p�i���.
Bucket_AccuracyChartSummary             �o�Ӫ���ιϧ���ܤF�l��T���������ǽT��.
Bucket_BarChartSummary                  �o�Ӫ���ιϧ���ܤF���P�l���Ҧ��ڪ��ʤ���.  �o�P�ɭp��F�Q�������l��T���ƶq, �H�Υ������r���p��.
Bucket_LookupResultsSummary             �o�Ӫ�����ܤF�P�����إ��󵹩w�r�����p���i���.  ���C�Ӷl���ӻ�, �o���|��ܥX�Ӧr���o�ͪ��W�v, �r���|�X�{�b�Ӷl���ت��i���, �H�η��Ӧr���X�{�b�l��T���خ�, ���Ӷl���o��������v�T.
Bucket_WordListTableSummary             �o�Ӫ��洣�ѤF�S�w�l���إ������r���M��, ���Ӷ}�Y���r���v�C��z.
Magnet_MainTableSummary                 �o�Ӫ�����ܤF�l�K�M��, �o�ǧl�K�O�Ψӫ��өT�w�W�h��l��T���[�H������.  �C�@�C���|��ܥX�l�K�p��Q�w�q��, ������̪��l��, �٦��ΨӧR���ӧl�K�����s.
Configuration_MainTableSummary          �o�Ӫ���t���ƭӪ���, ���p���� POPFile ���պA.
Configuration_InsertionTableSummary     �o�Ӫ���t���@�ǫ��s, �P�_�O�_�n�b�l��T�����e���l��Τ�ݵ{���e, ����ק���Y�ΥD���C.
Security_MainTableSummary               �o�Ӫ��洣�ѤF�X�ձ���, ��v�T POPFile ����պA���w��, �O�_�n�۰��ˬd�{����s, �H�άO�_�n�� POPFile �į�έp��ƪ��@���T�Ǧ^�{���@�̪�������Ʈw.
Advanced_MainTableSummary               �o�Ӫ��洣�ѤF�@�� POPFile �����l��T���ɩҷ|�������r���M��, �]���L�̦b�@��l��T���ت����p�L���W�c.  �o�̷|�Q���Ӧr���}�Y���r�a�Q�v�C��z.

Imap_Bucket2Folder                      '<b>%s</b>' �l�����H��ܶl��X
Imap_MapError                           �p�����W�L�@�Ӫ��l���������@���l��X��!
Imap_Server                             IMAP ���A���D���W��:
Imap_ServerNameError                    �п�J���A�����D���W��!
Imap_Port                               IMAP ���A���s����:
Imap_PortError                          �п�J���Ī��s���𸹽X!
Imap_Login                              IMAP �b���n�J:
Imap_LoginError                         �п�J�ϥΪ�/�n�J�W��!
Imap_Password                           IMAP �b�����K�X:
Imap_PasswordError                      �п�J�n�Ω���A�����K�X!
Imap_Expunge                            �q�Q�ʵ����H��X�زM���w�Q�R�����l��T��.
Imap_Interval                           ��s���j����:
Imap_IntervalError                      �п�J���� 10 ���� 3600 ���������j.
Imap_Bytelimit                          �C�ʶl��T���n�ΨӤ������줸�ռ�. ��J 0 (��) ���ܧ��㪺�l��T��:
Imap_BytelimitError                     �п�J�ƭ�.
Imap_RefreshFolders                     ���s��z�l��X�M��
Imap_Now                                �{�b!
Imap_UpdateError1                       �L�k�n�J. �����ҩp���n�J�W�ٸ�K�X.
Imap_UpdateError2                       �s���ܦ��A������. ���ˬd�D���W�ٸ�s����, �ýнT�{�p���b�u�W.
Imap_UpdateError3                       �Х��պA�s�u�Ӹ`.
Imap_NoConnectionMessage                �Х��պA�s�u�Ӹ`. ���p������, �o�@���شN�|�X�{��h�i�Ϊ��ﶵ.
Imap_WatchMore                          �Q�ʵ��l��X�M�檺�l��X
Imap_WatchedFolder                      �Q�ʵ����l��X�s��
Imap_Use_SSL                            �ϥ� SSL

Shutdown_Message                        POPFile �w�g�Q�����F

Help_Training                           ���p�즸�ϥ� POPFile ��, �oԣ�]�����ӻݭn�Q�[�H�ձ�. POPFile ���C�@�Ӷl�����ݭn�ζl��T���ӥ[�H�ձ�, �馳���p���s��Y�ӳQ POPFile ���~�������l��T�����s�����쥿�T���l����, �ׯu���O�b�ձЦo. �P�ɩp�]�o�]�w�p���l��Τ�ݵ{��, �ӫ��� POPFile ���������G�[�H�L�o�l��T��. ����]�w�Τ�ݹL�o������T�i�H�b <a href="http://getpopfile.org/docs/FAQ:EmailSorting">POPFile ���p�e</a>�سQ���.
Help_Bucket_Setup                       POPFile ���F "������ (unclassified)" �����l���~, �ٻݭn�ܤ֨�Ӷl��. �� POPFile ���W�S���B���b��o��q�l�l�󪺰Ϥ���ө�, �p�Ʀܥi�H�����N�ƶq���l��. ²�檺�]�w�|�O�� "�U�� (spam)", "�ӤH (personal)", �M "�u�@ (work)" �l��.
Help_No_More                            �O�A��ܳo�ӻ����F