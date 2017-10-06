function Aufbereitung2
% Aufbereitung v2
% INPUT/Benötigte Umgebung: Subfunktionen(flut2.m, infobox.m, movingaverage.m, leporidae.m, panzoom.m), Pfad zu Rohdaten im textformat (Doppelpunkt-delimited 
% header mit Datenreihennamen in Zeile 5 bis 8; Zeitreihen in Spalten, mittels Tabs getrennt), Eine Datei für die Ergebnisse (wird sonst generiert).
% Siehe auch unter "Konfiguration".
% OUTPUT: Eintrag in Ergebnis.mat
%
% Version: 1.0
% Datum: 2017-10-06
% Autor: Peter Jüstel
% Lizenz: CC-BY-SA 4.0 (Feel free, but attribute the author, and share remixes under similar terms)
% https://creativecommons.org/licenses/by-sa/4.0/
% https://creativecommons.org/licenses/by-sa/4.0/legalcode


%%%% README
%
%%% Softwaresuite Architektur
% Die Software arbeitet mit einer zentralen Datei "Ergebnis.mat". Diese enthält ein Structure Array mit dem Namen "Versuch", und den Feldern
% .Beschreibung, .Dateiname, .Datengrenzen, .Kalibration, .Messpunkte, usw.
% Im üblichen Nutzungsszenario sollen in neuen Zeitreihen zuerst die Kalibratioins- und Messpunkte definiert werden. Dafür ist
% Aufbereitung.m zuständig. Anschließend können diese aufbereiteten Daten für die Extraktion, Darstellung und interpretation genutzt
% werden. 
%
%%% Datenstruktur:
% Versuch = struct([]);
% Versuch(versuchsnummer).Dateiname = '';		% Name der Datei mit den Versuchsdaten
% Versuch(vnum).Beschreibung = '';				% Beschreibung des Versuchs
% Versuch(vnum).Versuchsdatengrenzen = [];		% Wenn in einer Datei mehrere Versuche sind, können Grenzen definiert werden, die einen Versuch eingrenzen. Das skaliert die Darstellung.
% Versuch(vnum).*Intervalltyp* = [];			% Die Intervalle innerhalb der Zeitreihe, welche zu einem gewissen Typ gehören. Z.B. Messdaten, oder Kalibrationsdaten
%
%%% Andere Eingangsdaten nutzen (bezüglich Format):
% Der Ladevorgang zwischen Zeile 201 und 211 muss angepasst werden ("% Versuchsdaten laden" und "% Header parsen")
% Damit das Programm funktioniert, muss nach diesem Abschnitt eine Matrix M existieren, die die Zeitreihen als Spalten enthält. Die erste Spalte
% wird aktuell als Zeitstempel der Messpunkte interpretiert, und deshalb ignoriert (siehe definition der Variable "t"). Weiterhin muss ein 1xn cellarray mit namen "head" existieren,
% welches in den Zellen strings enthält. Diese strings werden später als Bezeichnungen für die Zeitreihen in dem GUI genutzt.
%
%%% Einen weiteren Intervalltyp (e.g. Messdaten, Kalibration, Schubmessung,...) hinzufügen: 
% 1) Das Feld in der "Versuch" Struktur hinzufügen, und speichern:>> Versuch(vnum).Intervalltyp = []; save('Ergebnis.mat','Versuch').
% 2) Einen Radiobutton hinzufügen (s. definition von Clustersradiogroup und radio2), und buttonhoehe, string, Position und UserData anpassen.
% 3) Evtl. Position der clustersradiogroup ändern.
%
%%% Ein neuer Versuch wird definiert, indem in der Konfiguration (siehe unten) die Versuchsnummer 0 eingetragen wird. Der rest des Prozesses ist
% geführt.
%
%%% Grobstruktur dieser Funktion: Präambel/Konfiguration(->wählen des Versuchs, oder neuer Versuch), Laden/erstellen der "Versuch" struct Variable
% (benötigt/erzeugt Ergebnisdatei), Laden und parsen der Daten, Aufbauen der GUI, <Userinput über GUI>, Speicherknopf-> Backup der Ergebnisdatei und
% speichern der aktualisierten "Versuch"-Variable in der Ergebnisdatei.



%%%% TODO / known Bugs
%
% - Bei Darstellung in Zeiteinheiten speichert das Programm die X-werte trotzdem als Indices. -> Achseneinheiten und Datenextraktion entkoppeln.
% - Clustergrenzen bezüglich "Anfang" und "Ende" sortieren, wenn man sie übereinander hinwegzieht.
% - Validieren, dass alle Felder des Struct "Versuch" da sind, wenn Versuch geladen ist.
% - Wenn die Selectionchangefunction der intervalle nen Fehler wirft, kann es sein, dass ein Feld mit Daten eines anderen überschrieben wird (z.B. wenn
% - Diverses nicht da ist, wird es mit den Daten des vorher gewählten Feldes überschrieben).
% - Manager für die Ergebnisdatei, bzw. das Versuchs-struct. (Versuche sortieren und löschen können).
% - Errors abfangen die auftauchen, wenn man außerhalb von den Daten Intervallgrenzen erschaffen will, oder sie dort hinziehen will.
% - manchmal fallen ein paar intervallbeschriftungen auf, indem sie außerhalb der achse angezeigt werden. 'Clipping', 'on' ?
% - Umlaute sind flasch enkodiert in Windows? -> Dateikodierung irgendwo mitteilen, dass matlab for windofs das UTF-8 checkt.



%%%% Präambel

%clc
%clear all
close all
clear Versuch
CWD = pwd;	% current working directory abspeichern.


%%%% Konfiguration

vnum = 01;												% Wähle Versuchsnummer. Für neue Daten: vnum = 0. Wenn unbekannt, siehe nächste Zeile.
beschreibung_switch = 0;							% Flag; Gespeicherte Versuchsbeschreibungen und Zuordnungen anzeigen, und danach Ausführung stoppen.
selectedothersplotswitch = 0;						% Flag; Weitere Zeitreihen im extrafenster plotten?
	auswahl = [9 3 15:17];							% [9 3 15:17]Wenn Selectedothersplotswitch = true: Welche Datenreihen dargestellt werden sollen. Siehe auch die "head" Struktur, welche dynamisch ausgelesen wird, oder die Notizen am Ende dieser Funktion. [3 22 7 8 19]
xachseneinheiten = false;								% Nur für die Darstellung verwenden! Für die Bearbeitung der Intervalle ist eine x-achse in Zeiteinheiten ungeeignet. Flag; Ob auf der X-Achse der Datenindex oder die Zeit aufgetragen werden soll.
mittelungsbreite = 100;									% Filter: Radius der Mittelung um den aktuellen Punkt (Mittelungsradius; nur 1 und 2; Standard=100)
Ergebnisdatei = 'BeispielErgebnis.mat';							% Name der Datei, in der die Ergebnisse gespeichert sind. Diese muss im selben Ordner liegen. Wenn noch nicht vorhanden, gewünschten Dateinamen hier angeben.
Versuchsdatenpfad = [CWD, filesep, 'Versuchsdaten'];	% Systemabhängig formatierter Pfad zum Ordner mit den Versuchsdaten. Standard: ./Versuchsdaten
Subfunktionspfad = [CWD, filesep, 'Subfunktionen'];		% Systemabhängig formatierter Pfad zu den Subfunktionen, z.B. flut2.m
Backuppfad = [CWD, filesep, 'Ergebnisbackups'];			% Systemabhängig formatierter Pfad zu den Backups



%%%% Daten Laden, Neue Versuchsnummern erstellen, Neue Ergebnisdateien erzeugen,...

addpath(Subfunktionspfad)	% Matlab sagen, wo es die Subfunktionen findet.

% Informationen über Versuche laden.
if exist([CWD, filesep, Ergebnisdatei],'file')	% Testen, ob Ergebnisdatei im selben Ordner, wie diese Funktion liegt,
	load([CWD, filesep, Ergebnisdatei]);
	if exist('Versuch','var') == 0 || isstruct(Versuch) == 0 || isfield(Versuch, 'Dateiname') == 0
		error([Ergebnisdatei, ' muss ein Structure Array mit Namen "Versuch", und den entsprechenden Feldern enthalten.'])
	end
	
	% Alle Versuchsbeschreibungen anzeigen
	if beschreibung_switch == 1
		disp('Versuchbeschreibungen werden angezeigt. beschreibung_switch = true')
		disp('- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -')
		for ii = 1:size(Versuch, 2)		 %#ok<*NODEF>
			disp(['Versuch (', num2str(ii), ') - ',Versuch(ii).Dateiname,' : ', Versuch(ii).Beschreibung])	% Durch alle Versuche laufen, und Beschreibungen anzeigen. Dann Skript beenden.
			if mod(ii,5) == 0
				% alle 5 Versuche einen optischen trenner.
				disp('- - - - -')
			end
		end
		assignin('base','Versuch',Versuch)	% Die Daten aus der Ergebnisdatei in den Basisworkspace laden, zum anschauen.
		return
	end
else											% andernfalls eine neue Ergebnisdatei anlegen.
	antwort = questdlg(['Matlab kann ', [CWD, filesep, Ergebnisdatei], ' nicht finden. Soll eine neue Datenstruktur erzeugt werden? Durch den Savebutton kann anschließend eine neue ',Ergebnisdatei, ' erzeugt werden.'], 'Neue Ergebnisdatei', 'Ja', 'Abbrechen', 'Abbrechen'); % questdlg(Dialogtext, Titeltext, Button 1, Button 2, Button 3, Default Button)
	if strcmp(antwort, 'Ja')
		Versuch = struct([]);
		Versuch(1).Dateiname = '';		% Name der Datei mit den Versuchsdaten
		Versuch(1).Beschreibung = '';	% Beschreibung des Versuchs
		Versuch(1).Versuchsdatengrenzen = [];	% Wenn in einer Datei mehrere Versuche sind, können Grenzen definiert werden, die einen Versuch darstellen.
		Versuch(1).Kalibration = [];	% Die Intervalle in der Zeitreihe, welche zur Kalibration gehören.
		Versuch(1).Schubmessung = [];	% Zwei Intervalle, welche "An" und "Aus" repräsentieren.
		Versuch(1).Messdaten = [];		% Die Intervalle innerhalb der Zeitreihe, welche zu den Messpunkten gehören.
		Versuch(1).Diverses = [];		% für alles, was man Sonst so im Versuch nebenbei macht.
		vnum = 0;						% Im nächsten Schritt kann dann der Dateiname eingegeben werden.
	else
		disp(['Matlab kann ', [CWD, filesep, Ergebnisdatei], ' nicht finden. Ausführung Abgebrochen.'])	% evtl. durch uiopen dialog, oder neu erschaffen, ersetzen.
		return
	end
end



% Daten zu Versuch Nummer "vnum" laden
if vnum == 0
	
	% neuen Versuch einlesen
	NeueDatei = inputdlg({'Bitte den Dateinamen der Versuchsdaten-Datei eingeben:'}, 'Neuer Versuch', 1, {'tank8_0'});	% inputdlg(Fenstertext, Fenstertitel, Inputzeilenanzahl, Default Antwort)
	if isempty(NeueDatei)	% wenn "Abbrechen" gedrückt wurde
		return
	else
		NeueDatei = NeueDatei{1};
	end
	
	% Sanity checks
	if size(NeueDatei, 2) == 0
		error('Keine Datei angegeben.')
	elseif exist([Versuchsdatenpfad, filesep, NeueDatei],'file') == 0
		error(['Datei nicht gefunden: ', Versuchsdatenpfad, filesep, NeueDatei])
	end
	
	% Prüfen, ob die Datei schon bei irgendeinem Versuch benutzt wird.
	a = {Versuch.Dateiname};		% cell array mit allen Dateinamen.
	neuerversuchflag = 0;
	for ii = 1:size(a,2)
		if strcmp(a{ii}, NeueDatei) == 1
			disp(['Datei wird schon bei Versuch Nummer ', num2str(ii), ' genutzt. Versuchsbeschreibung: ', Versuch(ii).Beschreibung])
			neuerversuchflag = 1;
		end
	end
	
	% Dialogbox, wenn die Datei bereits bei einem anderen Versuch benutzt wird.
	if neuerversuchflag == 1
		antwort2 = questdlg(['Versuche mit zugeordneter Datei ', NeueDatei, ' existieren bereits. Optionen:'], 'Datei existiert', 'Neue Versuchsnummer', 'Abbrechen', 'Abbrechen'); % questdlg(Dialogtext, Titeltext, Button 1, Button 2, Button 3, Default Button)
		if strcmp(antwort2, 'Neue Versuchsnummer') == 1
			Versuch(end+1).Dateiname = NeueDatei;	% Neue Versuchsnummer mit bestehendem Dateinamen erzeugen.
			Versuch(end).Beschreibung = '';			% Zu dieser Versuchsnummer (ja, da muss "end" nicht "end+1" stehen), die Beschreibung initialisieren.
			vnum = size(Versuch, 2);
		else
			disp('Abgebrochen. Eventuell die Versuchsnummer bei der Konfiguration eintragen.')
			% Es wurde Abbrechen oder das Kreuz gedrückt.
			return
		end
	else

		if exist('antwort', 'var')
			vnum = 1;			% Der erste Versuch muss hier ein bisschen speziell behandelt werden. Er braucht schon Feldzuweisungen, damit alles reibungsfrei läuft (s.o.). Allerdings kann dann nicht "hinten angehängt" werden, weil sonst die erste Zeile leer bleibt.
			Versuch(1).Dateiname = NeueDatei;
		else
			% Alles lief glatt. Neuen Versuch erzeugen.
			Versuch(end+1).Dateiname = NeueDatei;	% Neue Versuchsnummer mit bestehendem Dateinamen erzeugen.
			Versuch(end).Beschreibung = '';		% Zu dieser Versuchsnummer (ja, da muss "end" nicht "end+1" stehen), die Beschreibung initialisieren.
			vnum = size(Versuch, 2);
		end
	 
	end
elseif vnum < 0 || round(vnum) ~= vnum		% Sanity check
	error('vnum muss Null oder eine positive, ganze Zahl sein.')
elseif vnum <= size(Versuch, 2)
	% Ein existierender Versuch wurde gewählt. Gehe weiter zum import der Daten.
else
	error(['Keine Daten unter der Versuchsnummer ', num2str(vnum)])
end
assignin('base','Versuch',Versuch)	% Die Daten aus der Ergebnisdatei in den Basisworkspace laden, zum anschauen.

% Versuchsdaten einlesen
if isempty(Versuch(vnum).Dateiname) % Sanity Checks
	error(['Kein Dateiname zu Versuch(', num2str(vnum), ') definiert.'])
elseif exist([Versuchsdatenpfad, filesep, Versuch(vnum).Dateiname], 'file')	% wenn es zu der Versuchsnummer tatsächlich einen Versuch gibt: Daten laden.
	
	% Versuchsdaten laden.
	M = importdata([Versuchsdatenpfad, filesep, Versuch(vnum).Dateiname]);		
	assignin('base','Rohdaten',M)
	
	% Parsen des Headers
	head = cell(4,1);
	for ii = 1:4
		head{ii} = strread(M.textdata{ii+4,1},'%s','delimiter',':'); %#ok<DSTRRD> % Aus den Textdaten die Spaltennamen separieren.
	end
	head = vertcat(head{:});		% ein einzelnes langes Cellarray draus machen.
	assignin('base','Header',head)	
	M = M.data;
else
	error(['Kann Daten zu Versuchsnummer ', num2str(vnum), ' am Ort ' [Versuchsdatenpfad, filesep, Versuch(vnum).Dateiname], ' nicht finden.'])
end



%%%% GUI für Aufbereitung der Daten

%%%% Graphikumgebung aufbauen

selectwindow = figure('units','normalized',... % normalized heißt: unabhängig von der Bildschirm/Fenstergröße geht es immer von 0 bis 1
					'Position',[0.05 0.128 0.95 0.8],... % Position: [left bottom width heights]
					'Color','w',...
					'NumberTitle', 'off',...			% Schaltet "Figure n" im Fenstertitel ab.
					'Name', ['Aufbereitung von Versuch ', num2str(vnum)],...
					'WindowButtonMotionFcn',@routing,... % WindowButtonMotionFcn: verknüpft die Funktion, welche beim "Motion" callback ausgelöst werden soll.
					'WindowButtonUpFcn',@routing,...
					'WindowScrollWheelFcn',@panzoom, ...
					'WindowKeyPressFcn', @panzoom,...
					'WindowKeyReleaseFcn', @panzoom);


uicontrol('Style', 'pushbutton',...
        'String','Info',...
        'units','normalized',...
        'BackgroundColor','w',...
        'FontSize',14,...
        'Position', [0.87 0.95 0.08 0.044],...
        'Callback',@infobox);


			
% Kontrollgruppen Radiobuttons
dataradiogroup = uibuttongroup('units', 'normalized',...	% enthält die Radiobuttons, mit denen die dargestellten Daten geändert werden können.
								'Position', [0.87 0.36 0.1 0.58],...
								'Title', 'Daten wählen:',...
								'FontSize', 12,...
								'SelectionChangeFcn', @selectdata);

clustersradiogroup = uibuttongroup('units', 'normalized',...	% enthält die radiobuttons, mit denen der Clustertyp (Messdaten, Kalibration, Diverses) ausgewählt werden kann.
								'Position', [0.87 0.22 0.1 0.126],...
								'Title', 'Intervallart wählen:',...
								'FontSize', 12,...
								'SelectionChangedFcn', @selectclustertype);
							
filterradiogroup = uibuttongroup('units', 'normalized',...	% enthält die radiobuttons, mit denen der Filter für die geglätteten Daten gewählt werden kann.
								'Position', [0.96 0.07 0.03 0.13],...
								'Title', 'Filter',...
								'FontSize', 10,...
								'SelectionChangeFcn', @selectfilter);



% Radiobuttons für die Datenwahl
radio1 = gobjects(size(M,2)-1);	% Initialisieren des Radiobutton Graphikobjekt arrays.
topslot = (1-0.02);						% Wird genutzt, um die Buttons von oben nach unten anzuordnen, und nicht andersherum. Siehe auch die Definition von 'Position'.

for ii = 1:length(radio1)
	buttonhoehe = topslot/length(radio1);		% Automatische Skalierung abhängig von der Anzahl Zeitreihen.
	buttonypos = topslot - (ii*buttonhoehe);	% Automatische Anordnung in der Höhe, abhängig von der Anhal der Zeitreihen. Die plätze werden oben nach unten belegt.
	radio1(ii) = uicontrol(dataradiogroup,...
					'Style', 'radiobutton',...
					'String', head{ii+1}, ...	% Wegen der Zeit auf position head{1} muss ii+1 -> d.h. die Namen der Zeitreihen fangen bei head{2} an.
					'Fontsize', 10,...
					'Units', 'normalized',...
					'Position', [0.05 buttonypos 0.95 buttonhoehe],...
					'UserData', ii+1);			% Diese Zahl ordnet dem Radiobutton die Zeitreihe zu.
end


% Radiobuttons für die Clusterwahl: Messdaten, Kalibration, Datengrenzen, Diverses
buttonhoehe = topslot/5;	% Für die Anordnung der Radiobuttons wichtige Größe

radio2.messdaten = uicontrol(clustersradiogroup,...
					'Style', 'radiobutton',...
					'string', 'Messdaten', ...
					'Fontsize', 10,...
					'Units', 'normalized',...
					'Position', [0.05 topslot-buttonhoehe 0.95 buttonhoehe],...
					'userdata', 'Messdaten');

radio2.Schubmessung = uicontrol(clustersradiogroup,...
					'Style', 'radiobutton',...
					'string', 'Schubmessung', ...
					'Fontsize', 10,...
					'Units', 'normalized',...
					'Position', [0.05 topslot-2*buttonhoehe 0.95 buttonhoehe],...
					'userdata', 'Schubmessung');
				
radio2.kalibration = uicontrol(clustersradiogroup,...
					'Style', 'radiobutton',...
					'string', 'Kalibration', ...
					'Fontsize', 10,...
					'Units', 'normalized',...
					'Position', [0.05 topslot-3*buttonhoehe 0.95 buttonhoehe],...
					'userdata', 'Kalibration');

radio2.datengrenzen = uicontrol(clustersradiogroup,...
					'Style', 'radiobutton',...
					'string', ['Grenzen Versuch(', num2str(vnum),')'], ...
					'Fontsize', 10,...
					'Units', 'normalized',...
					'Position', [0.05 topslot-4*buttonhoehe 0.95 buttonhoehe],...
					'userdata', 'Versuchsdatengrenzen');
				
radio2.diverses = uicontrol(clustersradiogroup,...
					'Style', 'radiobutton',...
					'string', 'Diverses', ...
					'Fontsize', 10,...
					'Units', 'normalized',...
					'Position', [0.05 topslot-5*buttonhoehe 0.95 buttonhoehe],...
					'userdata', 'Diverses'); %#ok<*STRNU>



% Radiogroup für die Filterwahl

radio3.zero = uicontrol(filterradiogroup,...
					'Style', 'radiobutton',...
					'string', '0', ...
					'Fontsize', 10,...
					'Units', 'normalized',...
					'Position', [0.187 0.7 0.67 0.20],...
					'userdata', 0);

radio3.one = uicontrol(filterradiogroup,...
					'Style', 'radiobutton',...
					'string', '1', ...
					'Fontsize', 10,...
					'Units', 'normalized',...
					'Position', [0.187 0.5 0.67 0.20],...
					'userdata', 1);

radio3.two = uicontrol(filterradiogroup,...
					'Style', 'radiobutton',...
					'string', '2', ...
					'Fontsize', 10,...
					'Units', 'normalized',...
					'Position', [0.187 0.3 0.67 0.20],...
					'userdata', 2);

radio3.three = uicontrol(filterradiogroup,...
					'Style', 'radiobutton',...
					'string', '3', ...
					'Fontsize', 10,...
					'Units', 'normalized',...
					'Position', [0.187 0.1 0.67 0.20],...
					'userdata', 3);



				
% Pushbuttons
uicontrol('Style', 'pushbutton',...
        'String','Flut',...
        'units','normalized',...
        'BackgroundColor','w',...
        'FontSize',12,...
        'Position', [0.87 0.165 0.08 0.044],...
        'Callback',@flutbutton);

uicontrol('Style', 'pushbutton',...
        'String','Leeren',...
        'units','normalized',...
        'BackgroundColor','w',...
        'FontSize',14,...
        'Position', [0.87 0.113 0.08 0.044],...
        'Callback',@clearclusters);

uicontrol('Style', 'pushbutton',...
        'String','Beschreibung',...
        'units','normalized',...
        'BackgroundColor','w',...
        'FontSize',12,...
        'Position', [0.87 0.061 0.08 0.044],...
        'Callback',@beschreibung_add);

savebutton = uicontrol('Style', 'pushbutton',...
        'String','Speichern',...
        'units','normalized',...
        'BackgroundColor','w',...
        'FontSize',14,...
        'Position', [0.87 0.009 0.08 0.044],...
        'Callback',@savebuttonpress);


					
%%%% Daten aufbauen

if xachseneinheiten == 1
	t = M(:,1);	% Zeit in Sekunden auf der X-Achse aufgetragen.
% 	t_ind = 1: length(M(:,1));		% WIP! Indices der Zeitdaten
else
	t = 1: length(M(:,1));		% Index auf der X-Achse aufgetragen.
end
tr = M(:,dataradiogroup.SelectedObject.UserData);		% Geplottete Daten.

% Moving Average Algorithmus, der Anfang und Ende vernachlässigt (startet erst ab b+1 Punkten und endet b Punkte vor Ende).
b = mittelungsbreite;					% Radius der Mittelung um den aktuellen Punkt (Mittelungsradius)
Tr = movingaverage(tr, 'mittelungsbreite', b, 'methode', 1);

if isempty(Versuch(vnum).Versuchsdatengrenzen) == 1
	mintr = min(tr);			% braucht es auch in @paintcluster
	maxtr = max(tr);			% braucht es auch in @paintcluster
	scalefactor = std(Tr-tr);	% Hier wird die Größe des Grenzbalkens skaliert, je nach dem wie verrauscht das Signal ist (skaliert mit der Standardabweichung).
elseif size(Versuch(vnum).Versuchsdatengrenzen, 2) == 2
	mintr = min( tr( Versuch(vnum).Versuchsdatengrenzen(1,1):Versuch(vnum).Versuchsdatengrenzen(1,2) ) );
	maxtr = max( tr( Versuch(vnum).Versuchsdatengrenzen(1,1):Versuch(vnum).Versuchsdatengrenzen(1,2) ) );
	scalefactor = std( Tr( Versuch(vnum).Versuchsdatengrenzen(1,1):Versuch(vnum).Versuchsdatengrenzen(1,2) ) - tr( Versuch(vnum).Versuchsdatengrenzen(1,1):Versuch(vnum).Versuchsdatengrenzen(1,2) ) );
else
	error('Die Inhalte oder Formatierung der Versuchsdatengrenzen sind vom Code nicht abgedeckt.')
end
	
if mintr == maxtr && mintr ~= 0		% für den Fall, dass die Funktion konstant ist.
	scalefactor = 0.1*mintr;
elseif mintr == maxtr && mintr == 0	% wenn die Funktion konstant null ist.
	scalefactor = 0.5;
end



%%%% Plot aufbauen

Achse1 = axes('units','normalized',...
			'Position',[0.05 0.08 0.8 0.9],...
			'XLim',[0 max(t)],...
			'YLim',[mintr maxtr+scalefactor],...
			'Tag', 'Achse1', ...
			'ButtonDownFcn', @panzoom);
		
if isempty(Versuch(vnum).Versuchsdatengrenzen) == 0
	Achse1.XLim = [t(Versuch(vnum).Versuchsdatengrenzen(1)), t(Versuch(vnum).Versuchsdatengrenzen(2))];		% Falls Versuchsgrenzen definiert wurden, wird die Ansicht entsprechend skaliert.
end

if xachseneinheiten == 1
	xlabel(head(1))
else
	xlabel('Datenpunkte')
end
ylabel(head(dataradiogroup.SelectedObject.UserData))

hold on
cmap = colormap(lines);		% Matrix mit Farbwertdaten auslesen
cmap = cmap(1:7, :);		% sinnvollen Teil abgreifen. die colormap wiederholt sich ab 8 einfach.

datenplot = plot(Achse1, t, tr, 'color', [0.8 0.8 0.8], 'ButtonDownFcn', @clustergenesis);
mittelplot = plot(Achse1, t, Tr, 'color',[0.2 0.2 0.2], 'ButtonDownFcn', @clustergenesis);
mittelplot.Visible = 'off';	% Wir brauchen das ding zwar definiert, aber es soll zunächst nicht angezeigt werden.

if isempty(Versuch(vnum).(clustersradiogroup.SelectedObject.UserData)) == 0		% Falls im Versuch(vnum) schon Cluster für die Messdaten definiet wurden.
	clusters = Versuch(vnum).(clustersradiogroup.SelectedObject.UserData);	% Cluster laden
	clgrenzen_objects = gobjects(size(clusters,1),size(clusters,2)+1);		% Array der Graphikobjekte initialisieren. Spalten: Clusteranfang, Clusterende, Clusternummer
	% Cluster einzeichnen
	for ii = 1:size(clusters,1)
		paintcluster(clusters(ii,:), ii)
	end
else
	clusters = [];
	clgrenzen_objects = gobjects(0);

end
	


%%%% Weitere Plots

if selectedothersplotswitch == 1
	figure('units','normalized','Position',[0 0 0.9875 0.8000], 'NumberTitle', 'off', 'Name', 'Selected Others')
	Auswahl = M(:,auswahl);	% ausgewählte Daten separieren
	for ii = 1:length(auswahl)
		subplot(length(auswahl), 1, ii)
		plot(M(:,1),Auswahl(:,ii))
		xlabel(head{1})
		ylabel(head{auswahl(ii)})
		grid on
		set(gca, 'XLim', [0 M(end,1)])
	end
end



%%%% Variablen initialisieren

actionflag = 0;		% determiniert, ob eine Intervallgrenze verschoben werden soll.
actioncluster = 0;	% hier wird abgespeichert, welches Intervall mit der action verbunden ist.
a_e = 1;			% hier wird abgespeichert, ob die GrenzeLinks oder GrenzeRechts bewegt werden soll.

newclusterflag = 0; % determiniert, ob gerade ein neuer Cluster erschaffen wird.
temp_object = gobjects(1,3);	% Zwischenspeicher für das gerade neu entstehende Intervall.

counter = 1;

%%%% Callback Funktionen

	function routing(src, evt)
		% Diese Funktion stellt den WindowButtonUpFcn und WindowButtonMotionFcn Callback mehreren Funktionen zur Verfügung.
		panzoom(src,evt)
		clusteraction(src,evt)
	end



	function selectclustertype(~,evt)
		% hier muss ich reinschreiben, was passiert, wenn ein radiobutton ausgewählt, oder verändet wird.
		% clustersradiogroup.SelectedObject -> gibt mir den radiobutton, der ausgewählt ist.
		% evt.OldValue ist das Handle des zuletzt ausgewählten Buttons
		
		% cluster in "Arbeits"-Versuch speichern
		Versuch(vnum).(evt.OldValue.UserData) = clusters;
		
		% clear graphix
		delete(clgrenzen_objects)       % Intervallgrenzen Graphikobjekte aus dem Plot entfernen
		clgrenzen_objects = gobjects(0);
		
		% neue cluster laden
		clusters = Versuch(vnum).(clustersradiogroup.SelectedObject.UserData);
		
		% plot clusters
		for jj = 1:size(clusters,1)
			paintcluster(clusters(jj,:),jj)
		end
	end



	function selectdata(~,~)
		% hier werden die den plots zugeordneten Daten geändert.
		
		if newclusterflag == 1	%wenn gerade ein neuer Cluster erschaffen werden soll
			delete(temp_object)						% temporäres Graphikobjekt löschen
			temp_object = gobjects(1,3);			% Platzhalter wieder anlegen.
			newclusterflag = 0;						% Flag zurücksetzen.
		end
		
		tr = M(:,dataradiogroup.SelectedObject.UserData);
		if filterradiogroup.SelectedObject.UserData == 0
			Tr = movingaverage(tr, 'mittelungsbreite', b, 'methode', 1);
		elseif filterradiogroup.SelectedObject.UserData < 4
			Tr = movingaverage(tr, 'mittelungsbreite', b, 'methode', filterradiogroup.SelectedObject.UserData);
		end
		
		if isempty(Versuch(vnum).Versuchsdatengrenzen) == 1
			mintr = min(tr);			% braucht es auch in @paintcluster
			maxtr = max(tr);			% braucht es auch in @paintcluster
			scalefactor = std(Tr-tr);	% Hier wird die Größe des Grenzbalkens skaliert, je nach dem wie verrauscht das Signal ist (skaliert mit der Standardabweichung).
		elseif size(Versuch(vnum).Versuchsdatengrenzen, 2) == 2
			mintr = min( tr( Versuch(vnum).Versuchsdatengrenzen(1,1):Versuch(vnum).Versuchsdatengrenzen(1,2) ) );
			maxtr = max( tr( Versuch(vnum).Versuchsdatengrenzen(1,1):Versuch(vnum).Versuchsdatengrenzen(1,2) ) );
			scalefactor = std( Tr( Versuch(vnum).Versuchsdatengrenzen(1,1):Versuch(vnum).Versuchsdatengrenzen(1,2) ) - tr( Versuch(vnum).Versuchsdatengrenzen(1,1):Versuch(vnum).Versuchsdatengrenzen(1,2) ) );
		else
			error('Die Inhalte oder Formatierung der Versuchsdatengrenzen sind vom Code nicht abgedeckt.')
		end
		datenplot.YData = tr;		% dem Plot die neuen Daten zuweisen
		mittelplot.YData = Tr;
		if mintr == maxtr && mintr ~= 0
            % für den Fall, dass die Funktion konstant ist.
            scalefactor = 0.1*mintr;
            Achse1.YLim = [0 maxtr+scalefactor];
        elseif mintr == maxtr && mintr == 0
			% wenn die Funktion konstant null ist.
            scalefactor = 0.5;
            Achse1.YLim = [-1 1];
		elseif mintr <= 0 && maxtr > 0
			% z.B. bei Schwankungen um den Nullwert.
			Achse1.YLim = [mintr maxtr];
		elseif mintr < 0 && maxtr <= 0
			% wenn alles im negativen liegt
			Achse1.YLim = [mintr 0];
		else
			% wenn alles normal ist
            Achse1.YLim = [0 maxtr+scalefactor];
		end
		
		if isempty(Versuch(vnum).Versuchsdatengrenzen) == 0
			Achse1.XLim = [t(Versuch(vnum).Versuchsdatengrenzen(1)), t(Versuch(vnum).Versuchsdatengrenzen(2))];
		else
			Achse1.XLim = [0 t(end)];
		end
		ylabel(head{dataradiogroup.SelectedObject.UserData})

		% Graphische Darstellung der Clustergrenzen anpassen.
        for jj = 1:size(clgrenzen_objects,1)
            y1 = tr(clusters(jj,1)) - scalefactor;		%  Hier wird die Größe des Balkens skaliert, je nach dem wie verrauscht das Signal ist (skaliert mit der Standardabweichung).
            y2 = tr(clusters(jj,1)) + scalefactor/2;
            clgrenzen_objects(jj,1).YData = [y1 y2];
            clgrenzen_objects(jj,2).YData = [y1 y2];
            clgrenzen_objects(jj,3).Position(2) = y1-scalefactor*0.2;
        end
		
	end



	function selectfilter(~,~)
		% Stellt anders gefilterte Daten dar
		if filterradiogroup.SelectedObject.UserData == 0
			mittelplot.Visible = 'off';
		elseif filterradiogroup.SelectedObject.UserData < 4
			mittelplot.Visible = 'on';
			mittelplot.YData = movingaverage(tr, 'mittelungsbreite', b, 'methode', filterradiogroup.SelectedObject.UserData);
		else
			error('wtf did just happen? filterradiogroup.SelectedObject.UserData ist 4 oder größer?')
		end
	end



	function clusteraction(src,evt)
		% cluster bewegen
		
		%%% ursprünglicher Plan (nicht unbedingt komplett wahrheitsgetreu):
		% Cluster erschaffen (input: clustertyp, Versuch.cluster, currentPosition, anfangEndeFlag, output: anfangEndeFlag, Graphikobjekt, Versuch.cluster(+1))
		% cluster aus konserve zeichnen (input: clustertyp, Versuch, Achsenhandle?, output: Graphikobjekt)
		%D grenze verschieben (input: clnummer, clustertyp, Versuch, actionflag, WindoButtonMotionFcn trigger, CurrentPosition, output: actionflag, clustergrenze, Graphikobjekt.Position)
		%D cluster löschen (input: clnummer)
		% Datengrenzen einzeichnen/ Plot skalieren.
		% Radiobutton Clustersorte änderung -> speichern, clear, neu laden, neu zeichnen.
		% funktion für die action, funktion fürs einzeichnen, funktion fürs sortieren.
		%%%

		if strcmp(evt.EventName, 'WindowMouseMotion') && actionflag == 1
			% Bewegung der Grenze
			X = round(Achse1.CurrentPoint(1,1));				% hole die aktuelle x-Position
			clgrenzen_objects(actioncluster, a_e).XData = [X X];	% verschiebe die Linie
			x1 = clgrenzen_objects(actioncluster, 1).XData(1,1);	% für die Berechnung der Schriftposition.
			x2 = clgrenzen_objects(actioncluster, 2).XData(1,1);
			if a_e == 1				% Wenn der Anfangsstrich gewählt wird, wird auch der Y-Wert verändert.
				y1 = tr(X) - scalefactor;
				y2 = tr(X) + scalefactor/2;
				clgrenzen_objects(actioncluster, 1).YData = [y1 y2];
				clgrenzen_objects(actioncluster, 2).YData = [y1 y2];
				clgrenzen_objects(actioncluster, 3).Position = [x1+round((x2-x1)/2) y1-scalefactor*0.2];
			elseif a_e == 2
				clgrenzen_objects(actioncluster, 3).Position(1,1) = x1+round((x2-x1)/2);	% Beim verschieben der hinteren Grenze soll er nur die x-position der Schrift verändern.
			end
		
		elseif strcmp(evt.EventName, 'Hit') && strcmp(src.Tag, 'GrenzeLinks') || strcmp(src.Tag, 'GrenzeRechts')
			% bewegung ermöglichen: flag und zu bewegende Grenze setzen.
			actionflag = 1;
			actioncluster = src.UserData;
			if strcmp(src.Tag, 'GrenzeLinks')
				a_e = 1;
			else
				a_e = 2;
			end

		elseif strcmp(evt.EventName, 'WindowMouseRelease')
			% bewegung aufhören
			if actionflag == 1
				clusters(actioncluster, a_e) = round(Achse1.CurrentPoint(1,1));		% Position der Grenze Speichern.
				actionflag = 0;
			end
		end
	end



	function paintcluster(cluster, clusternummer)
		% Clustergrenzen einzeichnen, und Handles in clgrenzen_objects ablegen.
		% INPUT: 2er Vektor mit Anfang und Ende des Clusters, globale Nummer des Clusters.
		% OUTPUT: Graphikobjekte in Achse1 für den Cluster
		
		clcolor = mod(clusternummer-1, 7) +1;	% cmap hat 7 Einträge. Danach muss wieder von vorn begonnen werden. Dafür sorgt die Modulo operation (Rest der Übrig bleibt, wenn man von der ersten Zahl möglichst viele ganze Vielfache der ersten Zahl abzieht)
		% Sanity checks
% 		if cluster(1) < 0	% this shit has problems mit xachseneinheiten == 1. cluster(1) kann 19500 sein, wenn die zeit in sekunden nur bis 2100 geht.
% 			cluster(1) = 0;
% 		elseif cluster(1) > t(end)
% 			cluster(1) = t(end);
% 		end
% 		if cluster(2) < 0
% 			cluster(2) = 0;
% 		elseif cluster(2) > t(end)
% 			cluster(2) = t(end);
% 		end
		
		% Intervall einzeichnen
		x1 = t(cluster(1));						% Intervallgrenze Anfang x-wert
		x2 = t(cluster(2));						% Intervallgrenze Ende x-wert				
		y1 = tr(cluster(1)) - scalefactor;		% Intervallgrenzen unterer y-wert
		y2 = tr(cluster(1)) + scalefactor/2;	% Intervallgrenzen oberer y-wert
		clgrenzen_objects(clusternummer,1) = plot(Achse1, [x1 x1], [y1 y2], 'LineWidth', 4, 'Color', cmap(clcolor,:), 'Tag', 'GrenzeLinks', 'UserData', clusternummer, 'ButtonDownFcn', @clusteraction);	% Anfangsgrenze zeichnen
		clgrenzen_objects(clusternummer,2) = plot(Achse1, [x2 x2], [y1 y2], 'LineWidth', 4, 'Color', cmap(clcolor,:), 'Tag', 'GrenzeRechts', 'UserData', clusternummer, 'ButtonDownFcn', @clusteraction);	% Endgrenze zeichnen
		clgrenzen_objects(clusternummer,3) = text(Achse1, x1+round((x2-x1)/2), y1-scalefactor*0.2, int2str(clusternummer), 'Color', cmap(clcolor,:), 'Tag', 'ClusterNummerierung', 'UserData', clusternummer, 'HorizontalAlignment','Center', 'ButtonDownFcn',@textButtonDown);	% Clusternummer einzeichnen.
	end



	function clustergenesis(~,evt)
		switch evt.Button
				case 1 % Linke-Mausaste
					
					if ~newclusterflag % es handelt sich um ein neues Cluster
						start = round(Achse1.CurrentPoint(1,1));	% Erste Intervallgrenze
						y1 = tr(start) - scalefactor; 
						y2 = tr(start) + scalefactor/2; 
						temp_object(1,1) = plot([start start], [y1 y2], 'LineWidth', 4, 'Color', [0.5 0.5 0.5], 'Tag', 'Temporäre Intervallgrenze', 'ButtonDownFcn', @clusteraction);	% erste Intervallgrenze zeichnen.
						
					else % finalisiere Cluster
						start = temp_object(1).XData(1,1);				% start des Clusters wieder auslesen, da dieser Wert nach dem ersten Durchlauf (~newclusterflag) gelöscht wird (s. Workspaces von Funktionen).
						ende = round(Achse1.CurrentPoint(1,1));
						
						if start < ende			% Sortiere die Grenzen richtigherum ein.
							tempcluster = [start ende];
						else
							tempcluster = [ende start];
						end
						if isempty(clusters) == 1
							splitnumber = 0;
						else
							splitnumber = length(find(clusters(:,1) < tempcluster(1,1)));	% finde die Nummer des nächsten clusters links vom neuen.
						end
						clusternum = splitnumber +1;
						
						
						% cluster einsortieren, und clgrenzen_objects aufbereiten /vorbereiten für @paintcluster
						if isempty(clusters) == 1
							clusters = tempcluster;
							clgrenzen_objects = temp_object;
						elseif splitnumber == 0							% cluster ist vor dem ersten
							clusters = [tempcluster; ...
										clusters];
							clgrenzen_objects = [temp_object; ...
												clgrenzen_objects];
											
						elseif splitnumber == length(clusters)	% cluster ist nach dem letzten
							clusters = [clusters; ...
										tempcluster];
							clgrenzen_objects = [clgrenzen_objects; ...
												temp_object];
											
						else										% cluster ist mittendrin
							clusters = [clusters(1:splitnumber,:); ...
											tempcluster; ...
											clusters(splitnumber+1:end,:)];
							clgrenzen_objects = [clgrenzen_objects(1:splitnumber,:); ...
												temp_object; ...
												clgrenzen_objects(splitnumber+1:end,:)];
						end
						
						% cluster richtig einzeichnen
						delete(temp_object)						% temporäres Graphikobjekt löschen
						temp_object = gobjects(1,3);			% Platzhalter wieder anlegen.
						paintcluster(tempcluster, clusternum)	% Jetzt den ordentlichen cluster zeichnen.
						

						% korrigieren der Intervallbeschriftungen, Farben, und Identifizierungsnummern
						for kk = 1:size(clgrenzen_objects,1)
							clcolor = mod(kk-1, 7) +1;										% s. @paintcluster für Erklärung
							set(clgrenzen_objects(kk,1), 'Color', cmap(clcolor,:), 'UserData', kk);			
							set(clgrenzen_objects(kk,2), 'Color', cmap(clcolor,:), 'UserData', kk);
							set(clgrenzen_objects(kk,3), 'Color', cmap(clcolor,:), 'UserData', kk, 'string',int2str(kk));	% und noch die Zahlenbeschriftung anpassen.
						end
						
					end
					newclusterflag = ~newclusterflag;
					
				case 3	% Rechte maustaste
					if exist('leporidae','file') && counter < 11
						leporidae(counter)
						counter = counter +1;
					else
						counter = 1;
					end
			end
	end



	function textButtonDown(src,~)  % Zum löschen eines Clusters, wenn man auf eine Intervallbeschriftung clickt.
		clusternummer = src.UserData;	
		if ~newclusterflag % falls die Erstellung eines neuen Clusters noch nicht abgeschlossen ist, lassen wir das besser.
            choice = questdlg(['Soll das Intervall Nummer ' int2str(clusternummer) ' wirklich gelöscht werden?'],'Intervall löschen?','Ja','Nein','Nein');		% Frage ob Cluster wirklich geloescht werden soll
			switch choice
				case 'Ja' % Wenn mit "Ja" beantwortet
					clusters(clusternummer,:) = [];			% lösche den Cluster in den Daten
					delete(clgrenzen_objects(clusternummer,:))	% Loesche alle zugehörigen Grafik-Elemente auf einmal
                    clgrenzen_objects(clusternummer,:)=[];		% Loesche auch die Object Handles in der clgrenzen Matix.
					
					% korrigieren der clgrenzen handles, der Intervallbeschriftungen und der Farben
					for kk = 1:size(clgrenzen_objects,1)
						clcolor = mod(kk-1, 7) +1;	% cmap hat 7 Einträge. Danach muss wieder von vorn begonnen werden. Dafür sorgt die Modulo operation (Rest der Übrig bleibt, wenn man von der ersten Zahl möglichst viele ganze Vielfache der ersten Zahl abzieht)
						set(clgrenzen_objects(kk,1), 'Color', cmap(clcolor,:), 'UserData', kk)
						set(clgrenzen_objects(kk,2), 'Color', cmap(clcolor,:), 'UserData', kk)
						set(clgrenzen_objects(kk,3), 'Color', cmap(clcolor,:), 'UserData', kk, 'string',int2str(kk))
					end
				otherwise % sonst, tu nix.
			end
		end
	end



	function flutbutton(~,~)
		% Wrapper Function für flut2.m, plus darstellung
		flutcluster = flut2(tr);	% Automatische Erkennung von stationären zuständen.
		clusters = sort([clusters; flutcluster],1);	% Einsortieren in bestehende Cluster
		
		% graphix anpassen. Vermutlich sind es viele Cluster, deshalb ein kompletter Reset.
		delete(clgrenzen_objects)				% Loesche alle zugehörigen Grafik-Elemente auf einmal
		clgrenzen_objects = gobjects(0);		% Loesche auch die Object Handles in der clgrenzen Matix.
		for jj = 1: size(clusters,1)
			paintcluster(clusters(jj,:), jj)
		end
		
	end



	function clearclusters(~,~)
		% Löscht alle cluster der aktuell gewählten Sorte.
		antwoort = questdlg(['Sollen wirklich alle ', clustersradiogroup.SelectedObject.UserData, ' Intervalle gelöscht werden?'],'Intervall löschen?','Ja','Nein','Ja');
		if strcmp(antwoort, 'Ja')
			clusters = [];			% lösche die Cluster in den Daten
			delete(clgrenzen_objects)	% Loesche alle zugehörigen Grafik-Elemente auf einmal
			clgrenzen_objects = gobjects(0);		% Loesche auch die Object Handles in der clgrenzen Matix.
		else
			return
		end
	end



	function beschreibung_add(~,~)
		% ermöglicht, die Beschreibung des aktuellen Versuchs zu bearbeiten.
		beschreibtemp = inputdlg(['Beschreibung von Versuch(', num2str(vnum),')                                   .'], 'Versuchsbeschreibung bearbeiten', 1, {Versuch(vnum).Beschreibung});	% inputdlg(Fenstertext, Fenstertitel, Inputzeilenanzahl, Default Antwort)
		if size(beschreibtemp,1) == 0
			% es wurde Abbrechen gedrückt
			return
		else
			% Beschreibung speichern.
			Versuch(vnum).Beschreibung = beschreibtemp{1};
		end
	end



	function savebuttonpress(~,~)
		if xachseneinheiten == true
			error('Darstellung in Zeiteinheiten. Daten werden zur sicherheit nicht gespeichert.')
		end
		%%%% Ergebnis abspeichern
		heute = datestr(date,'yyyy-mm-dd');
		if exist([CWD, filesep, Ergebnisdatei], 'file')
			movefile([CWD, filesep, Ergebnisdatei],[Backuppfad , filesep, heute,'_', Ergebnisdatei])		% Backup der Ergebnisdatei. Die aktuelle Ergebnisdatei wird in den Unterordner Ergebnisbackups verschoben, und das aktuelle Datum vorangestellt.
		end
		Versuch(vnum).(clustersradiogroup.SelectedObject.UserData) = clusters; % aktuelle Cluster und Versuch synchronisieren.
		assignin('base','Versuch',Versuch)					% den Inhalt von Versuch im basis Workspace unter "Versuch" speichern.
		save([CWD, filesep, Ergebnisdatei],'Versuch')		% Daten in Ergebnisdatei sichern.
		
		savebutton.BackgroundColor = [0.45 0.95 0.63];	% Visueller cue, dass gespeichert wurde.
		pause(0.8)
		savebutton.BackgroundColor = 'w';
	end

figure(selectwindow) % um das Hauptfenster auf jeden Fall als oberstes angezeigt zu bekommen.
% assignin('base','selectwindow',selectwindow)	% um sich u.a. die gobject Daten anschauen zu können

if xachseneinheiten == true
	warndlg('Eine Darstellung der X-Achseneinheiten in Sekunden führt auch dazu, dass die Intervallgrenzen in Sekunden gespeichert werden. Das beißt sich momentan noch mit Operationen auf den Intervallgrenzen, da dort Indices benötigt werden. In diesem Modus ist deshalb die Speicherfunktion deaktivert.');
end

end

%%%% Notizen

% head (8.9.2016): %%%%%%%%%%%%%%%%%%%%
%
%  1   'Zeit [s]'
%  2   'Spannung TW [V]'
%  3   'Strom TW [A]'
%  4   'Spannung SP [V]'
%  5   'Strom SP [A]'
%  6   'Tankdruck [mV]'
%  7   'Gas K [mg/s]'
%  8   'Gas A [mg/s]'
%  9   'Schub [mV]'
%  10  'TWasser AN [C]' -> Anodenkühlung
%  11  'TWasser KA [C]' -> Kathodenkühlung
%  12  'TWasser GH [C]' -> Gehäuse des Triebwerks kühlung
%  13  'TWasser SP [C]' -> Spulenkühlung
%  14  'TWasser ST [C]' -> Stromenkopplungskühlung
%  15  'TSchlauch AN [C]' -> Anodenabwasserschlauch
%  16  'TSchlauch SP [C]' -> Spulenabwasserschlauch
%  17  'T Kraftsensor [C]'
%  18  'Tankdruck PF [Pa]'
%  19  'Leistung TW [kW]'
%  20  'Leistung SP [kW]'
%  21  'Schub [mN]' -> behelfsmäßig in N umgerechnete mV Daten. Eigentlich ziemlich falsch.
%  22  'Fremdfeld [mT]'
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Ergebnis.m enthält struct Versuch(ii), mit Feldern .Beschreibung, .Dateiname, .Datengrenzen, .Kalibration, .Messpunkte

% load('Dateiname', optional 'variablenname')
% save('Dateiname.bak', 'Variablenname')
% save('Dateiname', 'Variablenname')

% Matlab Farben:
% Blau: [0 0.447, 0.741]
% Rot [0.85  0.325 0.098]
% Gelb: [0.929 0.694 0.125]
% Grün: [0.446 0.674 0.188]