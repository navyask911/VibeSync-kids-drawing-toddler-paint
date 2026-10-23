import React, { useState } from 'react';
import { 
  Copy, 
  Check, 
  Download, 
  FileCode, 
  FileText, 
  Settings2, 
  ShieldAlert, 
  Sparkles,
  ExternalLink
} from 'lucide-react';
import { 
  AdMobConfig, 
  GOOGLE_TEST_IDS, 
  generateAdHelperDart, 
  generateMainDart, 
  generateAndroidManifestXml, 
  generatePubspecYaml, 
  generateCOPPAComplianceChecklist,
  generateBuildGradle,
  generateProguardRules,
  generateKeyPropertiesExample,
  generateGitignore,
  generateAdMobUnitTestDart,
  generateMainActivityKt
} from '../data/flutterCode';

interface FlutterCodeViewerProps {
  config: AdMobConfig;
  onUpdateConfig: (newConfig: AdMobConfig) => void;
  isUsingTestIds: boolean;
  onToggleTestIds: (usingTest: boolean) => void;
}

type TabType = 
  | 'ad_helper' 
  | 'main' 
  | 'main_activity'
  | 'manifest' 
  | 'gradle' 
  | 'proguard' 
  | 'keyprops' 
  | 'pubspec' 
  | 'gitignore' 
  | 'test' 
  | 'checklist';

export const FlutterCodeViewer: React.FC<FlutterCodeViewerProps> = ({
  config,
  onUpdateConfig,
  isUsingTestIds,
  onToggleTestIds,
}) => {
  const [activeTab, setActiveTab] = useState<TabType>('ad_helper');
  const [copied, setCopied] = useState<boolean>(false);
  const [showConfigDrawer, setShowConfigDrawer] = useState<boolean>(false);

  const adHelperCode = generateAdHelperDart(config, isUsingTestIds);
  const mainDartCode = generateMainDart();
  const mainActivityKtCode = generateMainActivityKt();
  const manifestXmlCode = generateAndroidManifestXml(config.androidAppId);
  const pubspecYamlCode = generatePubspecYaml();
  const checklistMdCode = generateCOPPAComplianceChecklist();
  const buildGradleCode = generateBuildGradle();
  const proguardCode = generateProguardRules();
  const keypropsCode = generateKeyPropertiesExample();
  const gitignoreCode = generateGitignore();
  const testDartCode = generateAdMobUnitTestDart();

  const getActiveCode = () => {
    switch (activeTab) {
      case 'ad_helper': return { code: adHelperCode, filename: 'ad_helper.dart', language: 'dart' };
      case 'main': return { code: mainDartCode, filename: 'main.dart', language: 'dart' };
      case 'main_activity': return { code: mainActivityKtCode, filename: 'MainActivity.kt', language: 'kotlin' };
      case 'manifest': return { code: manifestXmlCode, filename: 'AndroidManifest.xml', language: 'xml' };
      case 'gradle': return { code: buildGradleCode, filename: 'build.gradle', language: 'groovy' };
      case 'proguard': return { code: proguardCode, filename: 'proguard-rules.pro', language: 'proguard' };
      case 'keyprops': return { code: keypropsCode, filename: 'key.properties.example', language: 'properties' };
      case 'pubspec': return { code: pubspecYamlCode, filename: 'pubspec.yaml', language: 'yaml' };
      case 'gitignore': return { code: gitignoreCode, filename: '.gitignore', language: 'gitignore' };
      case 'test': return { code: testDartCode, filename: 'admob_coppa_test.dart', language: 'dart' };
      case 'checklist': return { code: checklistMdCode, filename: 'COPPA_CHECKLIST.md', language: 'markdown' };
    }
  };

  const currentFile = getActiveCode();

  const handleCopy = () => {
    navigator.clipboard.writeText(currentFile.code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownload = () => {
    const blob = new Blob([currentFile.code], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = currentFile.filename;
    link.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-3xl overflow-hidden shadow-2xl flex flex-col">
      {/* 1. Header Toolbar */}
      <div className="bg-slate-950 px-6 py-4 border-b border-slate-800 flex flex-wrap items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <FileCode className="w-5 h-5 text-blue-400" />
            <h2 className="text-base font-bold text-white tracking-tight">
              Flutter & AdMob Reference Snippets
            </h2>
            <span className="text-xs px-2 py-0.5 rounded-full bg-blue-500/20 text-blue-400 border border-blue-500/30 font-medium">
              Flutter 3.x+ / google_mobile_ads ^5.2.0
            </span>
          </div>
          <p className="text-xs text-slate-400 mt-1">
            Illustrative source templates and ID configuration. These snippets are not the integrated app source and do not certify COPPA, GDPR-K, or Google Play Families Policy compliance.
          </p>
        </div>

        {/* Action Controls */}
        <div className="flex items-center gap-2">
          {/* Test vs Production Mode Toggle */}
          <div className="flex items-center bg-slate-900 p-1 rounded-xl border border-slate-800">
            <button
              onClick={() => onToggleTestIds(true)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                isUsingTestIds
                  ? 'bg-amber-500 text-slate-950 shadow-sm'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              Google Test IDs
            </button>
            <button
              onClick={() => onToggleTestIds(false)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                !isUsingTestIds
                  ? 'bg-blue-500 text-white shadow-sm'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              Live Production IDs
            </button>
          </div>

          <button
            onClick={() => setShowConfigDrawer(!showConfigDrawer)}
            className={`p-2 rounded-xl border text-xs font-semibold flex items-center gap-1.5 transition-colors cursor-pointer ${
              showConfigDrawer
                ? 'bg-blue-600 text-white border-blue-500'
                : 'bg-slate-800 text-slate-300 border-slate-700 hover:bg-slate-700'
            }`}
            title="Configure AdMob App and Unit IDs"
          >
            <Settings2 className="w-4 h-4" />
            <span className="hidden sm:inline">AdMob IDs</span>
          </button>

          <button
            onClick={handleCopy}
            className="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-white border border-slate-700 text-xs font-bold flex items-center gap-1.5 transition-all active:scale-95 cursor-pointer"
          >
            {copied ? (
              <>
                <Check className="w-4 h-4 text-emerald-400" />
                <span className="text-emerald-400">Copied!</span>
              </>
            ) : (
              <>
                <Copy className="w-4 h-4 text-slate-300" />
                <span>Copy File</span>
              </>
            )}
          </button>

          <button
            onClick={handleDownload}
            className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 transition-colors cursor-pointer"
            title="Download current file"
          >
            <Download className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* 2. Interactive AdMob ID Configuration Drawer (When toggled) */}
      {showConfigDrawer && (
        <div className="bg-slate-950/80 p-5 border-b border-slate-800 animate-fade-in text-xs">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <span className="font-bold text-white text-sm">AdMob Identifiers Injector</span>
              <span className="text-slate-400 text-xs">
                (Changes automatically update all code snippets below)
              </span>
            </div>
            <button
              onClick={() => onUpdateConfig(GOOGLE_TEST_IDS)}
              className="text-xs text-blue-400 hover:underline cursor-pointer"
            >
              Reset to Official Google Test IDs
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
            <div>
              <label className="text-[11px] text-slate-400 block font-mono mb-1">Android AdMob App ID</label>
              <input
                type="text"
                value={config.androidAppId}
                onChange={(e) => onUpdateConfig({ ...config, androidAppId: e.target.value })}
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-2.5 py-1.5 text-slate-200 font-mono text-[11px] focus:outline-none focus:border-blue-500"
              />
            </div>
            <div>
              <label className="text-[11px] text-slate-400 block font-mono mb-1">Android Banner Unit ID</label>
              <input
                type="text"
                value={config.androidBannerUnitId}
                onChange={(e) => onUpdateConfig({ ...config, androidBannerUnitId: e.target.value })}
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-2.5 py-1.5 text-slate-200 font-mono text-[11px] focus:outline-none focus:border-blue-500"
              />
            </div>
            <div>
              <label className="text-[11px] text-slate-400 block font-mono mb-1">Android Rewarded Unit ID</label>
              <input
                type="text"
                value={config.androidRewardedUnitId}
                onChange={(e) => onUpdateConfig({ ...config, androidRewardedUnitId: e.target.value })}
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-2.5 py-1.5 text-slate-200 font-mono text-[11px] focus:outline-none focus:border-blue-500"
              />
            </div>
            <div>
              <label className="text-[11px] text-slate-400 block font-mono mb-1">Android Interstitial Unit ID</label>
              <input
                type="text"
                value={config.androidInterstitialUnitId}
                onChange={(e) => onUpdateConfig({ ...config, androidInterstitialUnitId: e.target.value })}
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-2.5 py-1.5 text-slate-200 font-mono text-[11px] focus:outline-none focus:border-blue-500"
              />
            </div>
          </div>
        </div>
      )}

      {/* 3. File Tabs Navigation */}
      <div className="bg-slate-950 px-4 flex items-center gap-1 border-b border-slate-800 overflow-x-auto">
        <button
          onClick={() => setActiveTab('ad_helper')}
          className={`px-4 py-3 text-xs font-semibold flex items-center gap-2 border-b-2 transition-all cursor-pointer whitespace-nowrap ${
            activeTab === 'ad_helper'
              ? 'border-blue-500 text-blue-400 bg-slate-900/60'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <FileCode className="w-4 h-4" />
          <span>ad_helper.dart (Singleton)</span>
          <span className="text-[10px] bg-blue-500/20 text-blue-300 px-1.5 py-0.2 rounded font-mono">Core</span>
        </button>

        <button
          onClick={() => setActiveTab('main')}
          className={`px-4 py-3 text-xs font-semibold flex items-center gap-2 border-b-2 transition-all cursor-pointer whitespace-nowrap ${
            activeTab === 'main'
              ? 'border-blue-500 text-blue-400 bg-slate-900/60'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <FileCode className="w-4 h-4" />
          <span>main.dart (Canvas & Banner UI)</span>
        </button>

        <button
          onClick={() => setActiveTab('main_activity')}
          className={`px-4 py-3 text-xs font-semibold flex items-center gap-2 border-b-2 transition-all cursor-pointer whitespace-nowrap ${
            activeTab === 'main_activity'
              ? 'border-blue-500 text-blue-400 bg-slate-900/60'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <FileCode className="w-4 h-4 text-purple-400" />
          <span>MainActivity.kt (v2 Embedding)</span>
          <span className="text-[10px] bg-purple-500/20 text-purple-300 px-1.5 py-0.2 rounded font-mono">v2</span>
        </button>

        <button
          onClick={() => setActiveTab('manifest')}
          className={`px-4 py-3 text-xs font-semibold flex items-center gap-2 border-b-2 transition-all cursor-pointer whitespace-nowrap ${
            activeTab === 'manifest'
              ? 'border-blue-500 text-blue-400 bg-slate-900/60'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <FileText className="w-4 h-4" />
          <span>AndroidManifest.xml</span>
        </button>

        <button
          onClick={() => setActiveTab('gradle')}
          className={`px-4 py-3 text-xs font-semibold flex items-center gap-2 border-b-2 transition-all cursor-pointer whitespace-nowrap ${
            activeTab === 'gradle'
              ? 'border-blue-500 text-blue-400 bg-slate-900/60'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <FileCode className="w-4 h-4 text-amber-400" />
          <span>build.gradle (Signing & R8)</span>
          <span className="text-[10px] bg-amber-500/20 text-amber-300 px-1.5 py-0.2 rounded font-mono">Release</span>
        </button>

        <button
          onClick={() => setActiveTab('proguard')}
          className={`px-4 py-3 text-xs font-semibold flex items-center gap-2 border-b-2 transition-all cursor-pointer whitespace-nowrap ${
            activeTab === 'proguard'
              ? 'border-blue-500 text-blue-400 bg-slate-900/60'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <FileText className="w-4 h-4 text-cyan-400" />
          <span>proguard-rules.pro</span>
        </button>

        <button
          onClick={() => setActiveTab('keyprops')}
          className={`px-4 py-3 text-xs font-semibold flex items-center gap-2 border-b-2 transition-all cursor-pointer whitespace-nowrap ${
            activeTab === 'keyprops'
              ? 'border-blue-500 text-blue-400 bg-slate-900/60'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <FileText className="w-4 h-4 text-emerald-400" />
          <span>key.properties.example</span>
        </button>

        <button
          onClick={() => setActiveTab('pubspec')}
          className={`px-4 py-3 text-xs font-semibold flex items-center gap-2 border-b-2 transition-all cursor-pointer whitespace-nowrap ${
            activeTab === 'pubspec'
              ? 'border-blue-500 text-blue-400 bg-slate-900/60'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <FileText className="w-4 h-4" />
          <span>pubspec.yaml</span>
        </button>

        <button
          onClick={() => setActiveTab('gitignore')}
          className={`px-4 py-3 text-xs font-semibold flex items-center gap-2 border-b-2 transition-all cursor-pointer whitespace-nowrap ${
            activeTab === 'gitignore'
              ? 'border-blue-500 text-blue-400 bg-slate-900/60'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <FileText className="w-4 h-4 text-purple-400" />
          <span>.gitignore (Keystore Excluded)</span>
        </button>

        <button
          onClick={() => setActiveTab('test')}
          className={`px-4 py-3 text-xs font-semibold flex items-center gap-2 border-b-2 transition-all cursor-pointer whitespace-nowrap ${
            activeTab === 'test'
              ? 'border-blue-500 text-blue-400 bg-slate-900/60'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <FileCode className="w-4 h-4 text-emerald-400" />
          <span>admob_coppa_test.dart</span>
          <span className="text-[10px] bg-emerald-500/20 text-emerald-300 px-1.5 py-0.2 rounded font-mono">Tests</span>
        </button>

        <button
          onClick={() => setActiveTab('checklist')}
          className={`px-4 py-3 text-xs font-semibold flex items-center gap-2 border-b-2 transition-all cursor-pointer whitespace-nowrap ${
            activeTab === 'checklist'
              ? 'border-blue-500 text-blue-400 bg-slate-900/60'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <ShieldAlert className="w-4 h-4 text-emerald-400" />
          <span>COPPA Checklist</span>
        </button>
      </div>

      {/* 4. Code Display with Line Numbers and Highlighting */}
      <div className="relative bg-slate-950 p-4 font-mono text-xs overflow-x-auto text-slate-300 max-h-[620px] select-text">
        <pre className="leading-relaxed">
          <code>{currentFile.code}</code>
        </pre>
      </div>

      {/* 5. Footer Invariants Callout */}
      <div className="bg-slate-900 px-6 py-3 border-t border-slate-800 flex flex-wrap items-center justify-between text-xs text-slate-400 gap-3">
        <div className="flex items-center gap-3">
          <span className="text-emerald-400 font-semibold flex items-center gap-1">
            ✓ COPPA Tagged
          </span>
          <span className="text-emerald-400 font-semibold flex items-center gap-1">
            ✓ MaxAdRating: G
          </span>
          <span className="text-emerald-400 font-semibold flex items-center gap-1">
            ✓ NPA: '1'
          </span>
          <span className="text-blue-400 font-semibold flex items-center gap-1">
            ✓ Mid-Stroke Guard
          </span>
        </div>

        <div className="text-[11px] text-slate-500">
          File: <span className="font-mono text-slate-300">{currentFile.filename}</span>
        </div>
      </div>
    </div>
  );
};
