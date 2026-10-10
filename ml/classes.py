"""Canonical Class Definitions and Agronomic Metadata for Cotton Guard."""

from typing import List, Dict, Any

# 1. Canonical Disease Class Names (Must match exactly across ML, API, and Flutter)
CANONICAL_CLASSES: List[str] = [
    "Bacterial Blight",
    "Cotton Leaf Curl Virus",
    "Healthy Leaf",
    "Herbicide Growth Damage",
    "Leaf Hopper / Jassids",
    "Leaf Reddening",
    "Leaf Variegation"
]

# Directory folder name to Canonical Class mapping
FOLDER_TO_CLASS: Dict[str, str] = {
    "bacterial_blight": "Bacterial Blight",
    "curl_virus": "Cotton Leaf Curl Virus",
    "healthy_leaf": "Healthy Leaf",
    "herbicide_damage": "Herbicide Growth Damage",
    "leaf_hopper_jassids": "Leaf Hopper / Jassids",
    "leaf_reddening": "Leaf Reddening",
    "leaf_variegation": "Leaf Variegation"
}

CLASS_TO_FOLDER: Dict[str, str] = {v: k for k, v in FOLDER_TO_CLASS.items()}

# Class metadata containing symptoms, severity, treatment, and agronomic advisory
CLASS_METADATA: Dict[str, Dict[str, Any]] = {
    "Bacterial Blight": {
        "scientific_name": "Xanthomonas citri pv. malvacearum",
        "severity": "Moderate to High",
        "severity_level": 3,
        "is_healthy": False,
        "summary": "Water-soaked angular leaf spots bounded by veinlets, progressing to dark brown or black necrotic lesions.",
        "symptoms": [
            "Small water-soaked angular leaf spots bounded by veins",
            "Lesions turn reddish-brown then black necrotic",
            "Vein blight causing systemic leaf shedding",
            "Black arm symptoms on stems and water-soaked lesions on bolls"
        ],
        "treatment": [
            "Apply Copper Oxychloride 50 WP @ 2.5 g/L + Streptocycline @ 100 mg/L as foliar spray upon first symptom detection.",
            "Repeat spray after 12-15 days if humid or cloudy weather persists.",
            "Destroy and bury fallen infected plant debris to break pathogen cycle."
        ],
        "prevention": [
            "Treat planting seeds with Streptocycline (100 ppm) or hot water treatment before sowing.",
            "Adopt certified resistant or tolerant cotton cultivars (e.g., Bt cotton hybrids with resistance).",
            "Avoid excessive overhead flood irrigation and avoid high nitrogen applications during vegetative phase."
        ],
        "favorable_conditions": "High atmospheric humidity (>85%), intermittent rain showers, and temperatures between 28-32°C."
    },
    "Cotton Leaf Curl Virus": {
        "scientific_name": "Cotton Leaf Curl Multan Virus (CLCuV) / Begomovirus",
        "severity": "High to Critical",
        "severity_level": 4,
        "is_healthy": False,
        "summary": "Upward or downward leaf curling, vein thickening, enation (cup-like leafy outgrowths), and severe stunting.",
        "symptoms": [
            "Upward or downward cupping and curling of young terminal leaves",
            "Vein thickening prominently visible on the abaxial (lower) leaf surface",
            "Enations (small leaf-like outgrowths) on leaf undersides",
            "Shortened internodes leading to severe plant stunting and reduced boll formation"
        ],
        "treatment": [
            "Immediately manage the insect vector Whitefly (Bemisia tabaci) using Diafenthiuron 50 WP @ 1.25 g/L or Pyriproxyfen 10 EC @ 2 ml/L.",
            "Rogue out and safely incinerate heavily infected early-stage plants to halt field spread.",
            "Install yellow sticky traps @ 15-20 per acre for continuous whitefly population monitoring."
        ],
        "prevention": [
            "Sow virus-resistant or tolerant certified cotton hybrids suited to your agro-climatic zone.",
            "Maintain wide border crops (bajra, maize, or sorghum) as biological barriers against whiteflies.",
            "Eradicate alternate weed hosts (Abutilon indicum, Parthenium hysterophorus) in and around field bunds."
        ],
        "favorable_conditions": "High temperatures (30-40°C) with dry spells followed by humidity, which spur whitefly multiplication."
    },
    "Healthy Leaf": {
        "scientific_name": "Gossypium hirsutum (Normal Vigorous Foliage)",
        "severity": "None",
        "severity_level": 0,
        "is_healthy": True,
        "summary": "Foliage exhibits vibrant green chlorophyll, intact venation, balanced turgor pressure, and zero disease lesions.",
        "symptoms": [
            "Uniform vibrant green coloration across leaf lamina",
            "Clean, intact leaf margins without necrotic edges or curling",
            "Smooth epidermal tissue free of insect punctures, frass, or honeydew",
            "Healthy apical growth and robust flower/boll development"
        ],
        "treatment": [
            "No chemical intervention required.",
            "Continue standard agronomic practices and maintain regular scout monitoring twice weekly.",
            "Apply balanced micronutrient foliar spray (Zinc, Boron, Magnesium) during peak squaring and flowering."
        ],
        "prevention": [
            "Maintain soil moisture at 50-60% field capacity; avoid waterlogging.",
            "Follow soil-test-based N-P-K fertilizer schedules with split nitrogen applications.",
            "Ensure regular border weed eradication and beneficial pollinator protection."
        ],
        "favorable_conditions": "Optimal cotton growth occurs at 25-34°C with ample sunlight and well-drained loamy soil."
    },
    "Herbicide Growth Damage": {
        "scientific_name": "Phytotoxicity / Herbicide Drift Syndrome",
        "severity": "Moderate",
        "severity_level": 2,
        "is_healthy": False,
        "summary": "Epinasty, parallel leaf venation, strapping, interveinal chlorosis, or feathering caused by synthetic auxin or non-selective herbicide drift.",
        "symptoms": [
            "Finger-like strapping or shoestring leaf distortion (auxin herbicide drift such as 2,4-D or Dicamba)",
            "Interveinal yellowing, bleaching, or chlorotic mottling (glyphosate or triazine injury)",
            "Stiffened, brittle petioles and curved stems (epinasty)",
            "Stunted terminal growth points and premature blossom drop"
        ],
        "treatment": [
            "Avoid panic defoliation or aggressive chemical treatments; allow crop to metabolize residues.",
            "Apply light irrigation and foliar spray of 19:19:19 (NPK) @ 5 g/L + humic acid @ 2 ml/L to stimulate recovery.",
            "Spray gibberellic acid (GA3) @ 10-20 ppm if terminal growth remains locked for over 10 days."
        ],
        "prevention": [
            "Use dedicated spray equipment for cotton and never use herbicide sprayers without triple decontamination.",
            "Avoid spraying non-selective herbicides on windy days (wind speed > 8 km/h) near cotton fields.",
            "Install drift-reduction nozzles and maintain proper boom height during adjacent weed control."
        ],
        "favorable_conditions": "High winds, temperature inversions during aerial or backpack spraying, or improper tank rinsing."
    },
    "Leaf Hopper / Jassids": {
        "scientific_name": "Amrasca biguttula biguttula (Hemiptera: Cicadellidae)",
        "severity": "Moderate to High",
        "severity_level": 3,
        "is_healthy": False,
        "summary": "Downward cupping, peripheral leaf yellowing, progressing to bronze margin necrosis known as 'hopperburn'.",
        "symptoms": [
            "Yellowing along the outer edges of the leaves (Grade I injury)",
            "Downward curling and cupping of leaf margins with marginal bronzing (Grade II injury)",
            "Extensive brick-red hopperburn necrosis leading to brittle leaf margins (Grade III/IV)",
            "Presence of small wedge-shaped yellowish-green nymphs walking diagonally on leaf undersides"
        ],
        "treatment": [
            "Spray Flonicamid 50 WG @ 0.3 g/L or Thiamethoxam 25 WG @ 0.2 g/L when ETL exceeds 2 nymphs/leaf.",
            "Alternatively, use Neem oil (Azadirachtin 10000 ppm) @ 2 ml/L as an eco-friendly IPM deterrent.",
            "Ensure targeted under-surface leaf canopy coverage during spraying."
        ],
        "prevention": [
            "Plant hairy/pubescent cotton varieties possessing natural mechanical resistance to jassid oviposition.",
            "Avoid excessive use of high nitrogenous fertilizers which render leaves succulent and attractive to jassids.",
            "Conserve natural predators such as Chrysoperla carnea (green lacewings) and ladybird beetles."
        ],
        "favorable_conditions": "Cloudy, humid weather with intermittent sunshine and moderate temperatures (27-33°C)."
    },
    "Leaf Reddening": {
        "scientific_name": "Physiological Anthocyanosis / Magnesium-Nitrogen Deficiency",
        "severity": "Low to Moderate",
        "severity_level": 2,
        "is_healthy": False,
        "summary": "Development of prominent red or purplish pigmentation in older leaves due to anthocyanin synthesis triggered by nutrient imbalances or cool nights.",
        "symptoms": [
            "Older and middle leaves turn purplish-red between veins while veins remain green",
            "Gradual decline in photosynthetic rate and premature senescence of affected foliage",
            "Under-developed bolls and reduced fiber maturity if left unaddressed during peak boll development",
            "Cold stress exacerbating reddening on the sun-exposed side of the canopy"
        ],
        "treatment": [
            "Foliar spray of 1% Magnesium Sulphate (MgSO4 @ 10 g/L) + 1% Urea @ 10 g/L twice at 10-day intervals.",
            "Apply Potassium Nitrate (13:0:45) @ 10 g/L during peak boll load to boost vascular translocation.",
            "Maintain balanced soil moisture; do not allow the root zone to suffer acute drought stress."
        ],
        "prevention": [
            "Apply soil Magnesium Sulphate @ 15-20 kg/acre during basal or vegetative field preparation.",
            "Avoid deep inter-cultivation that damages lateral feeder roots during boll formation.",
            "Maintain soil pH between 6.5 and 7.8 to facilitate micronutrient uptake."
        ],
        "favorable_conditions": "Sudden drop in night temperatures below 18°C combined with high daytime sunshine, or severe soil Mg/N depletion."
    },
    "Leaf Variegation": {
        "scientific_name": "Genetic / Chimeric Plastid Variegation",
        "severity": "Low",
        "severity_level": 1,
        "is_healthy": False,
        "summary": "Irregular mosaic-like patches of white, cream, or pale yellow on green leaves caused by somatic mutations in chlorophyll genes.",
        "symptoms": [
            "Sectorial or chimeral white or light yellow blotches on otherwise normal green leaf blades",
            "Asymmetric patterns without necrotic margins, fungal sporulation, or insect feeding scars",
            "Usually isolated to single branches or a very low percentage of plants in the plot",
            "Plant vigor remains generally normal unless variegation covers over 50% of total canopy"
        ],
        "treatment": [
            "No chemical or pesticide intervention is required or effective, as this is non-pathogenic.",
            "Monitor plant to differentiate from viral mosaic diseases (CLCuV) or severe herbicide drift.",
            "If only an isolated branch is affected, selective pruning may be done if desired for aesthetic uniformity."
        ],
        "prevention": [
            "Use certified, foundation-quality seed lines with high genetic purity.",
            "Maintain optimal nutrient feeding (Iron and Zinc chelate foliar spray) to rule out physiological chlorosis.",
            "Avoid selecting seed from variegated plants for subsequent generational sowing."
        ],
        "favorable_conditions": "Spontaneous genetic mutation; not influenced by weather, soil pathogens, or vector insects."
    }
}
