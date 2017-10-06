function [clusters, intervalle] = flut2(data, varargin)
% INPUT: stehender datenvektor; optional: mindestzahl Punkte (=mindestzeit) für eine stationären Zustand.
% OUTPUT: Matrix mit Zeilen, in denen Anfangs und Endpunkt der Mess-"punkte"/cluster drin stehen; optional: Aufteilungsintervalle der Y-achse
%
% Version: 1.0
% Datum: 2017-04-06
% Autor: Peter Jüstel
% Lizenz: CC-BY-SA 4.0 (Feel free, but attribute the author, and share remixes under similar terms)
% https://creativecommons.org/licenses/by-sa/4.0/
% https://creativecommons.org/licenses/by-sa/4.0/legalcode

%%%% Dokumentation
%
% Das Ziel von flut2 ist, stationäre Bereiche in einer Zeitreihe zu erkennen, und Informationen darüber in Form von Anfangs, und Endwerten 
% ("clusters") zurückzugeben. Der Gedanke hinter dem Algorithmus ist, dass in einem stationären Bereich viele Datenpunkte um einen y-wert liegen.
% Um diese Bereiche also zu finden, müssen zunächst die Bereiche der y-Achse gefunden werden, welchen viele Datenpunkte zugeordnet sind.
% Dazu kann man sich die Zeitreihe wie eine Grube vorstellen, die langsam mit Wasser geflutet wird (-> der Name). Bei "Wasserständen" mit stationären
% Bereichen werden besonders viele Datenpunkte gleichzeitig "überflutet". Praktisch umsetzen lässt sich diese Idee am leichtesten, indem die y-Achse 
% in Intervalle eingeteilt wird, welchen dann die Datenpunkte zugeordnet werden (ähnlich einem Histogramm). Indem alle Datenpunkte in y-Intervallen 
% mit zu wenigen Datenpunkten genullt werden, entsteht eine Segmentierung der Zeitreihe. Abschließend müssen diese Cluster nurnoch von Artefakten des
% Prozesses bereinigt werden. Viele Cluster sind sehr klein, da sie die Punkte enthalten, welche einem instationären Bereich angehören, aber im selben
% y-Intervall liegen, wie ein stationärer Bereich. Nachdem die Intervalle aufgrund ihrer Größe gefiltert sind, verbleiben im Idealfall nur die
% stationären Bereiche.
% Wie gut der Prozess funktioniert ist stark abhängig vom Rauschen. Die Inputdaten werden zwar geglättet, das funktioniert allerdings nur begrenzt, da
% mit zunehmendem Mittelungsradius die "Kanten" der stationären Bereiche abgeschliffen werden.
% 


%%%% TODO
%
% Sanity checking des inputs
% Bessere Methode das Rauschen zu entfernen.
% Wieso fangen manche Intervalle in der Mitte von anderen an? Eigentlich sollte es keine Überlappung geben.
% Zeile 64 ? -> was, wenn Intervalle leer sind


%%%% Manuelle Konfiguration des Algorithmus. Kommentare entfernen, zum aktivieren/nutzen.
% b = 100;			% Radius der Mittelung um den aktuellen Punkt (Mittelungsradius), fürs glätten der Daten.
% segs = 500;		% Anzahl der Intervalle für die äquidistante Aufteilung der Y-Achse. Sollte abhängt von den Schwankungen der Daten, und dem zu detektierenden Sprung gewählt werden.
% stationaer = 70;	% Mindstanzahl der Punkte (= mindestzeit) für einen stationären Zustand. Siehe hierzu "integrales Zeitmaß/integrated timescale".
% sloppyness = 5;	% wie viele Nullen(=Ausreißer in den Daten) ein Cluster verträgt, bevor er geschlossen und ein neuer begonnen wird.

showhistogram = 0;	% Auf 1 setzen für Hilfsplot zum Einstellen der Parameter. Zeigt Füllstände der Intervalle.
plotswitchflut2 = 0;	% Auf 1 setzen für Hilfsplot zum Einstellen der Parameter. Zeigt Die Daten mit Intervallen und Clustern.
%%%%


% Defaults
if exist('b','var') == 0
	b = 100;
end
if exist('segs','var') == 0
	segs = 500;
end
if exist('stationaer','var') == 0
	stationaer = 70;
end
if exist('sloppyness','var') == 0
	sloppyness = 5;
end

if nargin == 2
	stationaer = varargin{1};	% könnte sinnvoll sein, das übergeben zu können.
end


% 1) Daten glätten: Moving Average Algorithmus, der Anfang und Ende vernachlässigt (startet erst ab b Punkten und endet b+1 Punkte vor Ende).
Tr = movingaverage(data, 'mittelungsbreite', 100, 'methode', 1);
% Es ist wichtig, dass am Anfang und Ende von Tr Nullen stehen, sonst muss in h0rstor eine weitere Abbruchbedingung bei der sloppyness hinzugefügt werden, und das Padding am ende dieser Funktion angepasst werden.

% 2) Daten histogrammmäßig in Intervalle sortieren. Zusammensammeln der Punkte in einem Intervall -> speichern von [x, y]
[A, Indices, bin, intervalle] = hist0r(Tr, segs);

if showhistogram == true	% ein Hilfsplot für die Parametereinstellung
	figure
	bar(bin(:,2)-bin(:,1))
	hold on
	line([0 intervalle(end)],[stationaer stationaer], 'color', [0.7 0.6 0.1])
end


% 3) Die Einträge rausfinden, die zu wenige sind. D.h. diejenigen y-werte nullen, die nicht zu einer stationären Situation gehören.
for ii = 1:segs
	if bin(ii,2)-bin(ii,1) < stationaer && bin(ii,2)-bin(ii,1) ~= 0
		A(bin(ii,1):bin(ii,2)) = 0;		% Nullt alle Einträge, die im Histogramm zu wenige sind, d.h. nicht zu einer stationären Situation gehören.
	elseif bin(ii,2)-bin(ii,1) == 0 % wenn das intervall leer ist.
		%TODO
	end
end
% hier muss ich noch was machen, wenn bins einfach leer sind ([0 0]). Dann heult er nämlich rum.

% 4) Daten anhand der nullerlücken segmentieren.
[~, Indices] = sort(Indices,1);	% erzeugt den Vektor, mit dem die Sortierung rückgängig gemacht werden kann.
clusters = h0rstor(A(Indices), stationaer, sloppyness);


% 5) Den kompletten stationären Bereich erfassen, indem das "verwischen der Kanten" durch den Moving average Filter ausgeglichen wird.
clusters(:,1) = clusters(:,1) - round(0.75*b);
clusters(:,2) = clusters(:,2) + round(0.75*b);


if plotswitchflut2 == 1
	figure
	axes
	hold on
	
	for ii = 1:segs+1	% y-achsen intervalle einzeichnen
		line([0 length(data)],[intervalle(ii) intervalle(ii)], 'color', [0.8 0.8 0.8])
	end
	plot(A,'.')			% sortierte Daten einzeichnen
	for kk = 1:size(clusters,1)	% cluster einzeichnen
		x1 = clusters(kk,1);
		x2 = clusters(kk,2);
		y1 = A(clusters(kk,1)) - 100;
		y2 = A(clusters(kk,1)) + 50;
		line([x1 x1], [y1 y2], 'color', 'r');
		line([x2 x2], [y1 y2], 'color', 'r');
	end

end

end



function [A, In, bin, interva]= hist0r(data, segs)
% Input: stehender Vektor mit Daten, Anzahl der gewünschten
% Histogrammintervalle
% Output: Sortierte Daten, Indizes um die Sortierung rückgängig machen zu
% können, zuordnung der sortierten Daten zu den Histogrammintervallen (in
% Form von Anfangs- und Endindices innerhalb von A), intervalle der y-achse

	[A, In] = sort(data,1);						% sortiert die Daten nach y-wert. Raus kommt der sortierte Vektor A, und die zugehörigen Indices der Ursprungsordnung.
	l = length(A);
	interva = linspace(A(1), A(end), segs+1);
	bin = zeros(segs,2);						% in den bins werden nur anfangs und Endindex der zugehörigen Daten in A gespeichert.
	ii = 1;
	jj = 1;
	binanfang = 1;
	
	while ii <= l								% Durchlaufe alle Daten
		
		if A(ii) > interva(jj)					% check, ob datachunk noch in bin passt.
			bin(jj,:) = [binanfang ii-1];		% Speichere index von Anfang und Ende des Bins
			jj = jj +1;							% rücke in den nächsten bin
			binanfang = ii;						% aktueller index wird neuer binanfang
		end
		
		if ii == l
			bin(jj,:) = [binanfang ii];			% Ganz zum schluss muss noch das letzte Bin geschlossen werden.
		end
		
		ii = ii +1;								% gehe zu nächsten datachunk
		
	end
%  	plot(In, A, 'o')
end



function clusters = h0rstor(datas, stationa, sloppyness)
% Input: ergebnis von hist0r, minimale sinnvolle größe eines clusters, wie viele Nullen ein Cluster verträgt, bevor er abgeschlossen und ein neuer angefangen wird.
% Output: Vektor mit anfang und Ende der Cluster
	
	% Anfang und Ende von Brocken, anhand von Nullen dazwischen, bestimmen
	ll = length(datas);
	interfilt = zeros(ll,2);
	ii = 1;
	n = 0;
	b = datas ~= 0;		% binäres Register über die existenz von Daten
	
	% 	garbage = zeros(l,2);	% falls die zu kleinen Cluster jemals benötigt werden
	% 	nn = 0;

	while ii < ll
		
		if datas(ii) ~= 0
			jj = ii;	% Anfang des Clusters.
			while sum(b(ii:jj)) > (jj - ii)-sloppyness    % vorwärts laufen, bis sich zu viele (=sloppyness) Nullen angesammelt haben.
				jj = jj +1;
			end
			
			if jj-ii >= stationa	% testen, ob der Cluster groß genug ist.
				n = n +1;
				interfilt(n,:) = [ii jj];	% Anfang und Ende des groß genugen clusters speichern
% 			else
% 				nn = nn +1;
% 				garbage(nn,:) = [ii jj];	% Anfang und Ende des zu kleinen clusters speichern
			end
			
			ii = jj;	% weitersuchen hinter dem Cluster
		end
		
		ii = ii +1;
	end
	clusters = interfilt(1:n,:);	% Ergebnisvektoren auf tatsächliche Länge zusammenschrumpfen.
% 	garbage = garbage(1:nn,:);
end

