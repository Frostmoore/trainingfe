import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/forma/indici_di_forma.dart';

/// Stanchezza e carica — FASE 2-sexies, 20/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Una formula senza prove è un'opinione con dei decimali. ⚠️ E qui il rischio è
/// peggiore del solito: un indice sbagliato **non dà errore**, dà un numero — e
/// un numero sbagliato che sembra misurato è più convincente di una frase
/// sbagliata.
///
/// 💡 I casi che contano non sono «la formula fa il conto giusto» (quello è
/// aritmetica), ma i **limiti**: zero allenamenti, un giorno solo, il segno del
/// battito, e il giorno dopo una gara.
void main() {
  group('EWMA', () {
    /// 💡 Con una serie costante la media pesata è quel valore: è il controllo
    /// più stupido, ed è quello che prende un `alfa` scritto al contrario.
    test('una serie costante dà quel valore', () {
      expect(IndiciDiForma.ewma(List.filled(28, 400), 28), closeTo(400, 0.001));
    });

    /// ══ 🚨 L'ORDINE CONTA, ED È IL MODO PIÙ FACILE DI SBAGLIARE ══
    ///
    /// ⚠️ La serie va dal **più vecchio al più recente**. Invertirla non dà
    /// errore: dà un numero plausibile e sbagliato — che è precisamente il tipo
    /// di difetto che questo file esiste per prendere.
    test('pesa di più i giorni recenti', () {
      final salendo = IndiciDiForma.ewma([0, 0, 0, 0, 0, 0, 700], 7);
      final scendendo = IndiciDiForma.ewma([700, 0, 0, 0, 0, 0, 0], 7);

      expect(
        salendo,
        greaterThan(scendendo),
        reason: 'Un allenamento ieri conta più dello stesso di una settimana fa.',
      );
    });

    test('una serie vuota è zero, non un errore', () {
      expect(IndiciDiForma.ewma([], 7), 0);
    });
  });

  group('Stanchezza — ACWR', () {
    List<double> giorni(int quanti, double kcal) => List.filled(quanti, kcal);

    /// 🟢 Chi si allena sempre uguale sta nella sua zona normale: acuto e
    /// cronico coincidono, quindi il rapporto è 1.
    test('un carico costante dà circa 1, cioè la normalità', () {
      final i = IndiciDiForma.stanchezza(giorni(28, 400));

      expect(i.valore, closeTo(1, 0.05));
      expect(FasciaCarico.da(i.valore!), FasciaCarico.normale);
    });

    /// ══ 🚨 IL CASO PER CUI L'INDICE ESISTE ═════════════════════════════════
    ///
    /// Tre settimane tranquille e poi una settimana pesante: è **esattamente**
    /// la situazione in cui uno si fa male senza accorgersene, ed è quella che
    /// l'ACWR è nato per rendere visibile.
    test('una settimana pesante dopo tre tranquille alza l indice', () {
      final storia = [...giorni(21, 200), ...giorni(7, 900)];

      final i = IndiciDiForma.stanchezza(storia);

      expect(i.valore, greaterThan(1.5));
      expect(FasciaCarico.da(i.valore!), FasciaCarico.alto);
    });

    /// ⚠️ E il contrario: chi si ferma dopo un periodo carico è **scarico**, non
    /// «riposato» — l'indice non dà giudizi, dice solo dove sta rispetto al suo
    /// solito.
    test('fermarsi dopo un periodo carico abbassa l indice', () {
      final storia = [...giorni(21, 900), ...giorni(7, 0)];

      final i = IndiciDiForma.stanchezza(storia);

      expect(i.valore, lessThan(0.8));
      expect(FasciaCarico.da(i.valore!), FasciaCarico.scarico);
    });

    /// ══ 🚨 L'UNICO CASO SENZA NUMERO ═══════════════════════════════════════
    ///
    /// Zero allenamenti in ventotto giorni = **denominatore zero**. Non è «poco
    /// attendibile»: è una divisione impossibile. ⚠️ È l'unica differenza fra
    /// «non lo so ancora bene» e «non esiste», e le due cose non si mostrano
    /// allo stesso modo.
    test('senza nessun allenamento il numero NON esiste', () {
      final i = IndiciDiForma.stanchezza(giorni(28, 0));

      expect(i.valore, isNull);
      expect(i.esiste, isFalse);
    });

    /// 🚨 D-2s/A: con pochi giorni **il numero si calcola lo stesso**, e a dirlo
    /// è la nota accanto. ⚠️ Un valore che compare solo dopo ventotto giorni è,
    /// per chi installa l'app, una funzione che non esiste.
    test('con cinque giorni di storia il numero c è, ma lo dice', () {
      final i = IndiciDiForma.stanchezza(giorni(5, 400));

      expect(i.esiste, isTrue);
      expect(i.eAttendibile, isFalse);
      expect(i.giorniCheMancano, 23);
    });

    test('e a ventotto giorni non manca più niente', () {
      final i = IndiciDiForma.stanchezza(giorni(28, 400));

      expect(i.eAttendibile, isTrue);
      expect(i.giorniCheMancano, 0);
    });

    /// ⚠️ I giorni di riposo **contano come zero**, non si saltano. Saltandoli,
    /// il carico acuto sembrerebbe sempre pieno e l'indice non scenderebbe mai.
    test('i giorni di riposo abbassano il carico, non spariscono', () {
      final conRiposo = IndiciDiForma.stanchezza(
        [...giorni(21, 400), 400, 0, 0, 0, 0, 0, 0],
      );
      final senzaRiposo = IndiciDiForma.stanchezza(giorni(28, 400));

      expect(conRiposo.valore, lessThan(senzaRiposo.valore!));
    });
  });

  group('Carica', () {
    /// 💡 Tutto nella media personale = metà scala. È il punto di riferimento da
    /// cui si legge tutto il resto.
    test('tutto nella media dà 50', () {
      final i = IndiciDiForma.carica(
        zHrv: 0,
        zBattito: 0,
        zSonno: 0,
        nottiDiStoria: 30,
      );

      expect(i.valore, closeTo(50, 0.001));
    });

    test('sopra la propria media si sale', () {
      final i = IndiciDiForma.carica(
        zHrv: 1,
        zBattito: -1,
        zSonno: 1,
        nottiDiStoria: 30,
      );

      expect(i.valore, greaterThan(60));
    });

    /// ══ 🚨 IL SEGNO DEL BATTITO — l'errore più facile del file ══════════════
    ///
    /// Per HRV e sonno «più alto = meglio». Per il battito a riposo è il
    /// **contrario**: sopra la propria media è un segnale di stanchezza.
    ///
    /// ⚠️ Sbagliare questo segno darebbe un indice che **sale proprio quando
    /// dovrebbe scendere**, e nessuno se ne accorgerebbe guardando il numero.
    test('un battito ALTO abbassa la carica', () {
      final normale = IndiciDiForma.carica(
        zHrv: 0,
        zBattito: 0,
        zSonno: 0,
        nottiDiStoria: 30,
      );

      final battitoAlto = IndiciDiForma.carica(
        zHrv: 0,
        zBattito: 2,
        zSonno: 0,
        nottiDiStoria: 30,
      );

      expect(
        battitoAlto.valore,
        lessThan(normale.valore!),
        reason: 'Battito sopra la media = stanchezza, non forma.',
      );
    });

    /// 🚨 Il cibo entra **solo in negativo** — scelta nostra, dichiarata: del
    /// beneficio di mangiare tanto non sappiamo niente, del danno di mangiare
    /// troppo poco un po' sì.
    test('mangiare tanto NON alza la carica', () {
      final senza = IndiciDiForma.carica(
        zHrv: 0,
        zBattito: 0,
        zSonno: 0,
        nottiDiStoria: 30,
      );

      final mangiandoTanto = IndiciDiForma.carica(
        zHrv: 0,
        zBattito: 0,
        zSonno: 0,
        zCibo: 2,
        nottiDiStoria: 30,
      );

      expect(mangiandoTanto.valore, closeTo(senza.valore!, 0.001));
    });

    test('ma mangiare troppo poco la abbassa', () {
      final i = IndiciDiForma.carica(
        zHrv: 0,
        zBattito: 0,
        zSonno: 0,
        zCibo: -2,
        nottiDiStoria: 30,
      );

      expect(i.valore, lessThan(50));
    });

    /// ⚠️ Senza nessun ingrediente non si inventa un 50: **non c'è un valore**.
    /// Un 50 vorrebbe dire «perfettamente nella media», che è una conclusione e
    /// non un dato mancante.
    test('senza nessun ingrediente il numero non esiste', () {
      final i = IndiciDiForma.carica(
        zHrv: null,
        zBattito: null,
        zSonno: null,
        nottiDiStoria: 0,
      );

      expect(i.valore, isNull);
    });

    /// 💡 Un ingrediente solo basta a dare un numero: peggiora di **precisione**,
    /// non di esistenza. È la differenza con la stanchezza, che invece ha un
    /// caso in cui il numero non può proprio esserci.
    test('un ingrediente solo basta', () {
      final i = IndiciDiForma.carica(
        zHrv: 1,
        zBattito: null,
        zSonno: null,
        nottiDiStoria: 3,
      );

      expect(i.esiste, isTrue);
      expect(i.eAttendibile, isFalse);
      expect(i.giorniCheMancano, 4);
    });

    test('la scala non esce mai da 0–100', () {
      final altissimo = IndiciDiForma.carica(
        zHrv: 99,
        zBattito: -99,
        zSonno: 99,
        nottiDiStoria: 30,
      );

      final bassissimo = IndiciDiForma.carica(
        zHrv: -99,
        zBattito: 99,
        zSonno: -99,
        nottiDiStoria: 30,
      );

      expect(altissimo.valore, 100);
      expect(bassissimo.valore, 0);
    });
  });

  group('La nota di attendibilità — il difetto del 20/08', () {
    /// ══ 🚨 MISURARE LA STORIA SBAGLIATA ═══════════════════════════════════
    ///
    /// 📌 Il committente, provando l'app: *«non vedo "mancano N giorni"»*.
    ///
    /// ⚠️ La causa era nel provider, non qui: si guardava da quanto tempo
    /// l'archivio ha dati di **HRV**, e chi ripristina un backup ne ha subito
    /// ventotto giorni. 🚨 L'indice si dichiarava **attendibile** mentre
    /// l'`ACWR` era costruito su **un allenamento solo**.
    ///
    /// 💡 La finestra lunga dell'`ACWR` ha bisogno di ventotto giorni di
    /// **allenamenti osservati**, non di ventotto giorni di battiti. Questi test
    /// fissano la semantica che il provider deve rispettare.
    test('due giorni di storia dicono che ne mancano 26', () {
      final i = IndiciDiForma.stanchezza([0, 500])._come(2);

      expect(i.giorniCheMancano, 26);
      expect(i.eAttendibile, isFalse);
    });

    test('a ventotto non manca niente', () {
      final i = IndiciDiForma.stanchezza(List.filled(28, 300))._come(28);

      expect(i.giorniCheMancano, 0);
      expect(i.eAttendibile, isTrue);
    });

    /// ⚠️ E non si va sotto zero: chi ha cinquanta giorni di storia non ha
    /// «meno venti giorni da aspettare».
    test('con piu di ventotto giorni non si va sotto zero', () {
      final i = IndiciDiForma.stanchezza(List.filled(28, 300))._come(50);

      expect(i.giorniCheMancano, 0);
    });
  });

  group('z-score', () {
    test('il conto giusto', () {
      expect(
        IndiciDiForma.z(valore: 48, media: 65, deviazione: 10),
        closeTo(-1.7, 0.001),
      );
    });

    /// ══ ⚠️ Deviazione zero: `null`, non zero ══
    ///
    /// Tutti i giorni identici. 🚨 Rispondere `0` vorrebbe dire «perfettamente
    /// nella media», che è una **conclusione**; la verità è che lo scostamento
    /// non è calcolabile.
    test('con deviazione zero non si inventa uno zero', () {
      expect(IndiciDiForma.z(valore: 50, media: 50, deviazione: 0), isNull);
    });

    test('media e deviazione, e sotto i due valori non esistono', () {
      expect(IndiciDiForma.mediaEDeviazione([10]), isNull);

      final (media, dev) = IndiciDiForma.mediaEDeviazione([2, 4, 4, 4, 5, 5, 7, 9])!;

      expect(media, closeTo(5, 0.001));
      expect(dev, closeTo(2, 0.001));
    });
  });
}

/// 💡 `IndiciDiForma` è puro e non sa da quanto esiste l'archivio: glielo dice
/// chi i dati li ha letti. Qui si simula quello che fa `formaProvider`.
extension on Indice {
  Indice _come(int giorni) => Indice(
        valore: valore,
        giorniDiStoria: giorni,
        giorniPerEsserePieno: giorniPerEsserePieno,
      );
}
