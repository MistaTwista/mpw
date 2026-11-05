package mpw

import "testing"

const testMasterPassword = "banana colored duckling"

// Regression vectors captured from github.com/belogron/mpw, an independent
// Go implementation. They add non-ASCII names and sites and more counters to
// the reference vectors in testdata/testcases.xml.
var passwordVectors = []struct {
	fullName, site string
	counter        uint32
	resultType     ResultType
	want           string
}{
	{"Robert Lee Mitchell", "masterpasswordapp.com", 1, Maximum, "W6@692^B1#&@gVdSdLZ@"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 1, Long, "Jejr5[RepuSosp"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 1, Medium, "Jej2$Quv"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 1, Short, "Jej2"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 1, Basic, "WAo2xIg6"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 1, PIN, "7662"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 1, Name, "jejraquvo"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 1, Phrase, "jejr quv cabsibu tam"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 2, Maximum, "h3/BeMEiP(NlWgVjjTCc"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 2, Long, "GornJuci5/Zafs"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 2, Medium, "Gor0[Yek"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 2, Short, "Gor0"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 2, Basic, "hu80eME7"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 2, PIN, "8380"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 2, Name, "gorneyeka"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 2, Phrase, "gor juckakafe sigi"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 42, Maximum, "p7(TDgBNPt1o@QJheet$"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 42, Long, "BihnBevaMali3/"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 42, Medium, "Bih1*Zez"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 42, Short, "Bih1"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 42, Basic, "paX14qLN"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 42, PIN, "2761"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 42, Name, "bihnuzezo"},
	{"Robert Lee Mitchell", "masterpasswordapp.com", 42, Phrase, "bi nuzva cih cibotri"},
	{"Robert Lee Mitchell", "github.com", 1, Maximum, "L9'Oe4vYXYJnK6GaZbs)"},
	{"Robert Lee Mitchell", "github.com", 1, Long, "Vuya8_DoroVodv"},
	{"Robert Lee Mitchell", "github.com", 1, Medium, "Vuy5[Peh"},
	{"Robert Lee Mitchell", "github.com", 1, Short, "Vuy5"},
	{"Robert Lee Mitchell", "github.com", 1, Basic, "LxA5Vrg3"},
	{"Robert Lee Mitchell", "github.com", 1, PIN, "6985"},
	{"Robert Lee Mitchell", "github.com", 1, Name, "vuyqopehu"},
	{"Robert Lee Mitchell", "github.com", 1, Phrase, "vuyq peh heldosu niw"},
	{"Robert Lee Mitchell", "github.com", 2, Maximum, "w8$idDIYUBrsVK2WB0Z("},
	{"Robert Lee Mitchell", "github.com", 2, Long, "Hono9*LurkPade"},
	{"Robert Lee Mitchell", "github.com", 2, Medium, "Hon3:Bol"},
	{"Robert Lee Mitchell", "github.com", 2, Short, "Hon3"},
	{"Robert Lee Mitchell", "github.com", 2, Basic, "wIE3ncB9"},
	{"Robert Lee Mitchell", "github.com", 2, PIN, "2873"},
	{"Robert Lee Mitchell", "github.com", 2, Name, "honrubole"},
	{"Robert Lee Mitchell", "github.com", 2, Phrase, "honr bol kefdeqi yev"},
	{"Robert Lee Mitchell", "github.com", 42, Maximum, "a5+351%()YdHUuREJcI#"},
	{"Robert Lee Mitchell", "github.com", 42, Long, "SalaFaqkHamu4:"},
	{"Robert Lee Mitchell", "github.com", 42, Medium, "Sal5:Zok"},
	{"Robert Lee Mitchell", "github.com", 42, Short, "Sal5"},
	{"Robert Lee Mitchell", "github.com", 42, Basic, "azz59PfL"},
	{"Robert Lee Mitchell", "github.com", 42, PIN, "1555"},
	{"Robert Lee Mitchell", "github.com", 42, Name, "salruzoka"},
	{"Robert Lee Mitchell", "github.com", 42, Phrase, "sa ruzqa siq tokolde"},
	{"Robert Lee Mitchell", "сайт.рф", 1, Maximum, "T7$pu^%VV*87icaxYYYV"},
	{"Robert Lee Mitchell", "сайт.рф", 1, Long, "SigbMiqiPuxh1_"},
	{"Robert Lee Mitchell", "сайт.рф", 1, Medium, "Sig2:Gop"},
	{"Robert Lee Mitchell", "сайт.рф", 1, Short, "Sig2"},
	{"Robert Lee Mitchell", "сайт.рф", 1, Basic, "Tna29Hff"},
	{"Robert Lee Mitchell", "сайт.рф", 1, PIN, "7792"},
	{"Robert Lee Mitchell", "сайт.рф", 1, Name, "sigbugopi"},
	{"Robert Lee Mitchell", "сайт.рф", 1, Phrase, "si bugqi jah pivuhwe"},
	{"Robert Lee Mitchell", "сайт.рф", 2, Maximum, "ExGR$qN$AJC$72wKl@0%"},
	{"Robert Lee Mitchell", "сайт.рф", 2, Long, "NepzPowa0'Pisb"},
	{"Robert Lee Mitchell", "сайт.рф", 2, Medium, "NepZic4^"},
	{"Robert Lee Mitchell", "сайт.рф", 2, Short, "Nep7"},
	{"Robert Lee Mitchell", "сайт.рф", 2, Basic, "EK87dqo5"},
	{"Robert Lee Mitchell", "сайт.рф", 2, PIN, "7187"},
	{"Robert Lee Mitchell", "сайт.рф", 2, Name, "nepzicuda"},
	{"Robert Lee Mitchell", "сайт.рф", 2, Phrase, "nep powdagepo jeto"},
	{"Robert Lee Mitchell", "сайт.рф", 42, Maximum, "VID5LePRxuLY(WFIR19]"},
	{"Robert Lee Mitchell", "сайт.рф", 42, Long, "GixuXixd1:Xukf"},
	{"Robert Lee Mitchell", "сайт.рф", 42, Medium, "GixFoq5."},
	{"Robert Lee Mitchell", "сайт.рф", 42, Short, "Gix9"},
	{"Robert Lee Mitchell", "сайт.рф", 42, Basic, "VI89LGu3"},
	{"Robert Lee Mitchell", "сайт.рф", 42, PIN, "0289"},
	{"Robert Lee Mitchell", "сайт.рф", 42, Name, "gixfoqade"},
	{"Robert Lee Mitchell", "сайт.рф", 42, Phrase, "gix xixdemola rudi"},
	{"Иван Петров", "masterpasswordapp.com", 1, Maximum, "g7*h8iPgsUuLqY#@fkcF"},
	{"Иван Петров", "masterpasswordapp.com", 1, Long, "SitiJebpFamo3="},
	{"Иван Петров", "masterpasswordapp.com", 1, Medium, "Sit2*Gep"},
	{"Иван Петров", "masterpasswordapp.com", 1, Short, "Sit2"},
	{"Иван Петров", "masterpasswordapp.com", 1, Basic, "gaw22vPR"},
	{"Иван Петров", "masterpasswordapp.com", 1, PIN, "5742"},
	{"Иван Петров", "masterpasswordapp.com", 1, Name, "sitbigepa"},
	{"Иван Петров", "masterpasswordapp.com", 1, Phrase, "si bigbu nux wumespu"},
	{"Иван Петров", "masterpasswordapp.com", 2, Maximum, "A2?2%OdeiLaRmW*U7%yZ"},
	{"Иван Петров", "masterpasswordapp.com", 2, Long, "NimuQobaGadd4?"},
	{"Иван Петров", "masterpasswordapp.com", 2, Medium, "Nim4~Faf"},
	{"Иван Петров", "masterpasswordapp.com", 2, Short, "Nim4"},
	{"Иван Петров", "masterpasswordapp.com", 2, Basic, "ABC48OEt"},
	{"Иван Петров", "masterpasswordapp.com", 2, PIN, "2294"},
	{"Иван Петров", "masterpasswordapp.com", 2, Name, "nimqofafe"},
	{"Иван Петров", "masterpasswordapp.com", 2, Phrase, "ni qofba jud jerubla"},
	{"Иван Петров", "masterpasswordapp.com", 42, Maximum, "m1.d0I7y)%tMKXxSQvOe"},
	{"Иван Петров", "masterpasswordapp.com", 42, Long, "Yewo6%SuhqGudi"},
	{"Иван Петров", "masterpasswordapp.com", 42, Medium, "Yew3,Doh"},
	{"Иван Петров", "masterpasswordapp.com", 42, Short, "Yew3"},
	{"Иван Петров", "masterpasswordapp.com", 42, Basic, "msl3mIv4"},
	{"Иван Петров", "masterpasswordapp.com", 42, PIN, "0133"},
	{"Иван Петров", "masterpasswordapp.com", 42, Name, "yewqedoha"},
	{"Иван Петров", "masterpasswordapp.com", 42, Phrase, "yewq doh qeydivo saj"},
	{"Иван Петров", "github.com", 1, Maximum, "a0_vgp^B0L4F6CKgRcok"},
	{"Иван Петров", "github.com", 1, Long, "GahuSery6~Puge"},
	{"Иван Петров", "github.com", 1, Medium, "Gah9+Xuy"},
	{"Иван Петров", "github.com", 1, Short, "Gah9"},
	{"Иван Петров", "github.com", 1, Basic, "at29gZg2"},
	{"Иван Петров", "github.com", 1, PIN, "9029"},
	{"Иван Петров", "github.com", 1, Name, "gahsaxuye"},
	{"Иван Петров", "github.com", 1, Phrase, "gah seryexaya dazu"},
	{"Иван Петров", "github.com", 2, Maximum, "uxdf!bAPBTZkhIUiqY6]"},
	{"Иван Петров", "github.com", 2, Long, "LebaWebi4&Tofi"},
	{"Иван Петров", "github.com", 2, Medium, "LebYen0)"},
	{"Иван Петров", "github.com", 2, Short, "Leb0"},
	{"Иван Петров", "github.com", 2, Basic, "uK50ybA7"},
	{"Иван Петров", "github.com", 2, PIN, "3150"},
	{"Иван Петров", "github.com", 2, Name, "lebyenaju"},
	{"Иван Петров", "github.com", 2, Phrase, "leb webjurewo cuca"},
	{"Иван Петров", "github.com", 42, Maximum, "WERRSX2SDB1o&O&6wx0,"},
	{"Иван Петров", "github.com", 42, Long, "JoziQiqa2-Zasm"},
	{"Иван Петров", "github.com", 42, Medium, "JozZeg4@"},
	{"Иван Петров", "github.com", 42, Short, "Joz7"},
	{"Иван Петров", "github.com", 42, Basic, "WP77rJI0"},
	{"Иван Петров", "github.com", 42, PIN, "7377"},
	{"Иван Петров", "github.com", 42, Name, "jozzegumi"},
	{"Иван Петров", "github.com", 42, Phrase, "joz qiqmiyawa situ"},
	{"Иван Петров", "сайт.рф", 1, Maximum, "E2^Ha@yCk#X4CVtOa4Zd"},
	{"Иван Петров", "сайт.рф", 1, Long, "ZipfDawo0'Koph"},
	{"Иван Петров", "сайт.рф", 1, Medium, "Zip7=Miz"},
	{"Иван Петров", "сайт.рф", 1, Short, "Zip7"},
	{"Иван Петров", "сайт.рф", 1, Basic, "EA77sbL3"},
	{"Иван Петров", "сайт.рф", 1, PIN, "9277"},
	{"Иван Петров", "сайт.рф", 1, Name, "zipfumiza"},
	{"Иван Петров", "сайт.рф", 1, Phrase, "zip dawzacode rasa"},
	{"Иван Петров", "сайт.рф", 2, Maximum, "Zau1nAzcFEWZ%uW3uN2-"},
	{"Иван Петров", "сайт.рф", 2, Long, "YatlZumzYeje6:"},
	{"Иван Петров", "сайт.рф", 2, Medium, "YatLex1_"},
	{"Иван Петров", "сайт.рф", 2, Short, "Yat7"},
	{"Иван Петров", "сайт.рф", 2, Basic, "ZaK71mzA"},
	{"Иван Петров", "сайт.рф", 2, PIN, "2557"},
	{"Иван Петров", "сайт.рф", 2, Name, "yatlexezu"},
	{"Иван Петров", "сайт.рф", 2, Phrase, "ya lexmu cit morelzo"},
	{"Иван Петров", "сайт.рф", 42, Maximum, "DGh#DD1jwq$GqCqdbC9["},
	{"Иван Петров", "сайт.рф", 42, Long, "CubcBiloFodd7+"},
	{"Иван Петров", "сайт.рф", 42, Medium, "CubCuq7$"},
	{"Иван Петров", "сайт.рф", 42, Short, "Cub4"},
	{"Иван Петров", "сайт.рф", 42, Basic, "DGr44Dns"},
	{"Иван Петров", "сайт.рф", 42, PIN, "4424"},
	{"Иван Петров", "сайт.рф", 42, Name, "cubcuqici"},
	{"Иван Петров", "сайт.рф", 42, Phrase, "cu cuqlo cad pabowli"},
}

func TestSitePassword(t *testing.T) {
	masterKeys := map[string][]byte{}
	for _, v := range passwordVectors {
		mk, ok := masterKeys[v.fullName]
		if !ok {
			var err error
			mk, err = MasterKey(v.fullName, testMasterPassword)
			if err != nil {
				t.Fatal(err)
			}
			masterKeys[v.fullName] = mk
		}

		got, err := SitePassword(SiteKey(mk, v.site, v.counter), v.resultType)
		if err != nil {
			t.Fatalf("%+v: %v", v, err)
		}
		if got != v.want {
			t.Errorf("%s / %s / %d / %s: got %q, want %q", v.fullName, v.site, v.counter, v.resultType, got, v.want)
		}
	}
}

func TestPassword(t *testing.T) {
	got, err := Password("Robert Lee Mitchell", testMasterPassword, "masterpasswordapp.com", 1, Long)
	if err != nil {
		t.Fatal(err)
	}
	if want := "Jejr5[RepuSosp"; got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestSitePasswordUnknownType(t *testing.T) {
	if _, err := SitePassword(make([]byte, 32), "Nope"); err == nil {
		t.Error("expected error for unknown result type")
	}
}

func TestNewIdenticon(t *testing.T) {
	tests := []struct {
		fullName string
		want     Identicon
	}{
		{"Robert Lee Mitchell", Identicon{"╚☻╯⛄", 2}},
		{"Иван Петров", Identicon{"╰▓╝♜", 4}},
	}
	for _, tt := range tests {
		if got := NewIdenticon(tt.fullName, testMasterPassword); got != tt.want {
			t.Errorf("%s: got %+v, want %+v", tt.fullName, got, tt.want)
		}
	}
}

func TestIdenticonKeepsAllAccessories(t *testing.T) {
	for i, a := range accessories {
		if a == "" {
			t.Errorf("accessory %d is empty", i)
		}
	}
}

func TestParseResultType(t *testing.T) {
	for in, want := range map[string]ResultType{
		"x": Maximum, "Long": Long, "long": Long, "L": Long, "pin": PIN, "i": PIN, "Phrase": Phrase,
	} {
		got, err := ParseResultType(in)
		if err != nil || got != want {
			t.Errorf("ParseResultType(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	if _, err := ParseResultType("q"); err == nil {
		t.Error("expected error for unknown type")
	}
}

func TestEveryTypeHasTemplates(t *testing.T) {
	for _, rt := range ResultTypes {
		tpls, ok := templates[rt.Type]
		if !ok || len(tpls) == 0 {
			t.Errorf("%s: no templates", rt.Type)
		}
		for _, tpl := range tpls {
			for _, c := range tpl {
				if _, ok := templateChars[c]; !ok {
					t.Errorf("%s: template %q uses unknown class %q", rt.Type, tpl, c)
				}
			}
		}
	}
}
