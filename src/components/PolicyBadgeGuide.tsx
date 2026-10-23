import React from 'react';
import { ShieldCheck, Lock, AlertTriangle, Smartphone, Sparkles, CheckCircle2, Info } from 'lucide-react';

export const PolicyBadgeGuide: React.FC = () => {
  const compliancePillars = [
    {
      title: 'Global RequestConfiguration Precedence',
      tag: 'COPPA & GDPR-K Core',
      icon: <ShieldCheck className="w-5 h-5 text-emerald-400" />,
      codeSnippet: `RequestConfiguration(
  tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
  maxAdContentRating: MaxAdContentRating.g,
  tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
)`,
      description:
        'Must be applied via MobileAds.instance.updateRequestConfiguration() prior to MobileAds.instance.initialize(). This instructs Google AdMob and all mediated ad networks to treat every request as child-directed with strictly G-rated ad creative.',
    },
    {
      title: 'Mandatory Non-Personalized Ads (NPA)',
      tag: 'Zero Behavioral Tracking',
      icon: <Lock className="w-5 h-5 text-cyan-400" />,
      codeSnippet: `AdRequest(
  extras: <String, String>{
    'npa': '1', // Signals Non-Personalized Ads
  },
)`,
      description:
        'Google Play Families Policy strictly prohibits transmitting the Advertising ID (AAID) or IDFA for behavioral profiling. Setting npa: "1" enforces contextual-only ad matching based purely on app content category rather than user history.',
    },
    {
      title: 'Canvas Touch Isolation & Dead-Zone Buffer',
      tag: 'Toddler Ergonomics',
      icon: <Smartphone className="w-5 h-5 text-amber-400" />,
      codeSnippet: `// 1. Canvas gesture detector with boundary
// 2. Physical separator divider
Container(height: 12, color: Colors.amber[100])
// 3. Anchored bottom safe area banner
SafeArea(child: AdWidget(ad: bannerAd))`,
      description:
        'Toddlers frequently scribble near screen edges. Placing banner ads inside or directly overlapping the canvas triggers accidental click strikes from Google Play. Our architecture enforces a dedicated physical buffer and safe-area margins.',
    },
    {
      title: 'Active Drawing Sentinel (No Surprise Pop-ups)',
      tag: 'Family UX Policy',
      icon: <AlertTriangle className="w-5 h-5 text-rose-400" />,
      codeSnippet: `void showInterstitialAd({required bool isDrawingActive, ...}) {
  if (isDrawingActive) {
    debugPrint('AdHelper: Interstitial SUPPRESSED while drawing.');
    return;
  }
  _interstitialAd?.show();
}`,
      description:
        'Sudden full-screen ads that pop up while a child is mid-stroke cause immediate app uninstalls, 1-star reviews, and policy flags for deceptive or disruptive ads. The ad helper checks canvas drawing activity before showing any transition ad.',
    },
    {
      title: 'Parental Gate Before Monetized Unlocks',
      tag: 'Play Families Requirement',
      icon: <Sparkles className="w-5 h-5 text-purple-400" />,
      codeSnippet: `// Math Challenge Dialog
Text('$a + $b = ?') // Randomized adult arithmetic
// Upon adult verification -> Trigger Rewarded Ad`,
      description:
        'Google Play Families requires a parental gate whenever an action could result in an adult transaction or external commercial link. Math challenges verify adult comprehension before loading rewarded ad views.',
    },
  ];

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-3xl p-6 sm:p-8 shadow-xl">
      <div className="max-w-3xl mb-8">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-semibold mb-3">
          <ShieldCheck className="w-4 h-4" />
          Ad Safety Implementation Reference — Not Certification
        </div>
        <h2 className="text-2xl font-bold text-white tracking-tight">
          Ad Safety Implementation Reference for Child-Directed Apps
        </h2>
        <p className="text-sm text-slate-400 mt-2 leading-relaxed">
          Google Play enforces stringent guidelines on apps targeting children under 13.
          This reference describes some technical safeguards in <span className="font-mono text-slate-200">ad_helper.dart</span> and <span className="font-mono text-slate-200">main.dart</span>. It does not certify compliance or guarantee Play Store approval; review the current policies and the full app behavior before release.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {compliancePillars.map((pillar, idx) => (
          <div
            key={idx}
            className="p-5 rounded-2xl bg-slate-950 border border-slate-800/80 flex flex-col justify-between hover:border-slate-700 transition-colors"
          >
            <div>
              <div className="flex items-center justify-between mb-3">
                <div className="w-10 h-10 rounded-xl bg-slate-900 flex items-center justify-center border border-slate-800">
                  {pillar.icon}
                </div>
                <span className="text-[11px] font-mono font-medium text-slate-400 bg-slate-900 px-2 py-0.5 rounded border border-slate-800">
                  {pillar.tag}
                </span>
              </div>

              <h3 className="text-base font-bold text-white mb-2">{pillar.title}</h3>
              <p className="text-xs text-slate-400 leading-relaxed mb-4">{pillar.description}</p>
            </div>

            <div className="p-3 bg-slate-900/90 rounded-xl border border-slate-800 font-mono text-[11px] text-blue-300 overflow-x-auto">
              <pre>
                <code>{pillar.codeSnippet}</code>
              </pre>
            </div>
          </div>
        ))}
      </div>

      {/* Play Console Step-by-Step Instructions */}
      <div className="mt-8 p-6 rounded-2xl bg-gradient-to-r from-blue-950/40 via-indigo-950/30 to-purple-950/40 border border-blue-900/40">
        <h3 className="text-base font-bold text-white mb-3 flex items-center gap-2">
          <Info className="w-5 h-5 text-blue-400" />
          Google Play Console App Content Setup Instructions
        </h3>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs text-slate-300">
          <div className="p-3 bg-slate-950/60 rounded-xl border border-blue-800/20">
            <span className="font-bold text-white block mb-1">1. Target Audience</span>
            <span>Check "Ages 5 and under" or "Ages 6-8". This automatically enrols the app into the Designed for Families program.</span>
          </div>
          <div className="p-3 bg-slate-950/60 rounded-xl border border-blue-800/20">
            <span className="font-bold text-white block mb-1">2. Ads Declaration</span>
            <span>Declare ads accurately and confirm that every ad SDK and mediation network actually used is eligible for the current Google Play Families requirements.</span>
          </div>
          <div className="p-3 bg-slate-950/60 rounded-xl border border-blue-800/20">
            <span className="font-bold text-white block mb-1">3. Families Policy</span>
            <span>Confirm that all ads served are G-rated, non-personalized, and placed with safeguards against accidental toddler clicks.</span>
          </div>
        </div>
      </div>
    </div>
  );
};
