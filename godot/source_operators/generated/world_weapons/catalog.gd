extends RefCounted
# Actual source simpleWeaponModel plus the shared six-channel world detail kit; source rig chassis contacts, no rescaling.
const WEAPONS = [
	{
		"id": 0,
		"name": "Pulse Rifle",
		"file": "weapon-0.glb",
		"sha256": "7c2698e55cec533d3ca9ad1aeff8c5a80d07e9c70737c18439422eabe6d36f62",
		"bytes": 86076,
		"triangles": 1872,
		"draws": 4,
		"anchors": {
			"Muzzle": [
				0,
				0.01,
				-0.85
			],
			"WeaponGripLeft": [
				-0.11000000000000001,
				-0.09000000000000001,
				-0.22559999999999997
			],
			"WeaponGripRight": [
				0,
				-0.15500000000000003,
				-0.035
			]
		},
		"bounds": [
			[
				-0.09799999743700027,
				-0.27900001406669617,
				-0.8500000238418579
			],
			[
				0.0949999988079071,
				0.14300000667572021,
				0.35249999165534973
			]
		],
		"detail": {
			"triangles": 1260,
			"zones": {
				"mount": 12,
				"sight": 108,
				"ejection": 84,
				"feed": 156,
				"heat": 432,
				"muzzle": 276,
				"stock": 60,
				"grip": 84,
				"signature": 48
			},
			"materials": {
				"dark": true,
				"accent": true,
				"steel": true,
				"glow": true
			},
			"identity": {
				"id": 0,
				"short": "PULSE",
				"receiver": "slender carbine receiver with a low dorsal spine",
				"feed": "slim box magazine with a witness-slot body",
				"muzzle": "slotted flash hider in a long open perforated shroud",
				"stock": "extended skeleton-stock frame and cheek riser",
				"sight": "iron sights, rear notch over a supported front post",
				"accent": "teal energy strip and stepped fins",
				"signature": "open shroud hoops and three stepped fins above the port",
				"glow": true
			}
		}
	},
	{
		"id": 1,
		"name": "Rocket Launcher",
		"file": "weapon-1.glb",
		"sha256": "64009f5180d6fd7a63bd024b225465a00f3aa1a1387824c40d332eabc838bd62",
		"bytes": 74328,
		"triangles": 1620,
		"draws": 4,
		"anchors": {
			"Muzzle": [
				0,
				0,
				-0.76
			],
			"WeaponGripLeft": [
				-0.155,
				-0.13,
				-0.264
			],
			"WeaponGripRight": [
				0,
				-0.195,
				-0.035
			]
		},
		"bounds": [
			[
				-0.20600000023841858,
				-0.3190000057220459,
				-0.7900000214576721
			],
			[
				0.20600000023841858,
				0.20600000023841858,
				0.20000000298023224
			]
		],
		"detail": {
			"triangles": 1008,
			"zones": {
				"mount": 72,
				"sight": 108,
				"ejection": 72,
				"feed": 48,
				"heat": 300,
				"muzzle": 192,
				"stock": 48,
				"grip": 84,
				"signature": 84
			},
			"materials": {
				"dark": true,
				"accent": true,
				"steel": true,
				"glow": true
			},
			"identity": {
				"id": 1,
				"short": "ROCKET",
				"receiver": "continuous fat launch tube with a top carry handle",
				"feed": "breech latch with a loaded-cell window",
				"muzzle": "hollow trumpet blast-deflector bell",
				"stock": "flared rear venturi and shoulder rest pad",
				"sight": "iron sights seated on the tube spine",
				"accent": "orange warning chevrons and arming tab",
				"signature": "front trumpet and rear venturi pair",
				"glow": false
			}
		}
	},
	{
		"id": 2,
		"name": "Rail Lance",
		"file": "weapon-2.glb",
		"sha256": "ecbdffcf36f282e512651b00d7e22d1a35630d908bb192251fe9f311d27cea33",
		"bytes": 92504,
		"triangles": 1800,
		"draws": 4,
		"anchors": {
			"Muzzle": [
				0,
				0.025,
				-1.04
			],
			"WeaponGripLeft": [
				-0.11499999999999999,
				-0.07,
				-0.26880000000000004
			],
			"WeaponGripRight": [
				0,
				-0.135,
				-0.035
			]
		},
		"bounds": [
			[
				-0.10599999874830246,
				-0.2590000033378601,
				-1.1150000095367432
			],
			[
				0.10899999737739563,
				0.24500000476837158,
				0.257999986410141
			]
		],
		"detail": {
			"triangles": 1188,
			"zones": {
				"mount": 156,
				"sight": 468,
				"ejection": 84,
				"feed": 168,
				"heat": 60,
				"muzzle": 60,
				"stock": 60,
				"grip": 84,
				"signature": 48
			},
			"materials": {
				"dark": true,
				"accent": true,
				"steel": true,
				"glow": true
			},
			"identity": {
				"id": 2,
				"short": "RAIL",
				"receiver": "long sled with full-length separated accelerator rails",
				"feed": "underslung battery slab with a glowing charge window",
				"muzzle": "fork tips projecting past the bore",
				"stock": "slim fixed stock with a cheek riser and counterweight",
				"sight": "scope on a boxy raised plinth",
				"accent": "violet coil windings and charge window",
				"signature": "long twin rails and forward fork",
				"glow": true
			}
		}
	},
	{
		"id": 3,
		"name": "Scattergun",
		"file": "weapon-3.glb",
		"sha256": "d7f2a2713152881c73131608a57a628be5cfdd1e566cd1ddedfed9a7447e3030",
		"bytes": 89024,
		"triangles": 1916,
		"draws": 4,
		"anchors": {
			"Muzzle": [
				0,
				0.03,
				-0.82
			],
			"WeaponGripLeft": [
				-0.185,
				-0.06,
				-0.20159999999999997
			],
			"WeaponGripRight": [
				0,
				-0.125,
				-0.035
			]
		},
		"bounds": [
			[
				-0.20800000429153442,
				-0.24899999797344208,
				-0.8399999737739563
			],
			[
				0.21292324364185333,
				0.15595272183418274,
				0.2709999978542328
			]
		],
		"detail": {
			"triangles": 1124,
			"zones": {
				"mount": 12,
				"sight": 108,
				"ejection": 60,
				"feed": 156,
				"heat": 216,
				"muzzle": 336,
				"stock": 104,
				"grip": 84,
				"signature": 48
			},
			"materials": {
				"dark": true,
				"accent": true,
				"steel": true,
				"glow": true
			},
			"identity": {
				"id": 3,
				"short": "SCATTER",
				"receiver": "wide breech and broad fore-end with a break-action hinge",
				"feed": "extractor block and a side shell carrier",
				"muzzle": "wide twin bores in an upper/lower barrel band",
				"stock": "wide shotgun stock with a recoil pad",
				"sight": "ventilated raised rib and brass bead",
				"accent": "amber shell rims in the carrier and loops",
				"signature": "twin bores beneath a ventilated rib and selector lever",
				"glow": false
			}
		}
	},
	{
		"id": 4,
		"name": "Plasma Driver",
		"file": "weapon-4.glb",
		"sha256": "560a71e0984350e9eebec48fba2ade26f769dc82655f1e314674e62b9de47854",
		"bytes": 80908,
		"triangles": 1652,
		"draws": 4,
		"anchors": {
			"Muzzle": [
				0,
				0,
				-0.77
			],
			"WeaponGripLeft": [
				-0.135,
				-0.115,
				-0.2208
			],
			"WeaponGripRight": [
				0,
				-0.18,
				-0.035
			]
		},
		"bounds": [
			[
				-0.1420000046491623,
				-0.30399999022483826,
				-0.8299999833106995
			],
			[
				0.1420000046491623,
				0.14800000190734863,
				0.17999999225139618
			]
		],
		"detail": {
			"triangles": 1040,
			"zones": {
				"mount": 12,
				"sight": 108,
				"ejection": 84,
				"feed": 236,
				"heat": 304,
				"muzzle": 116,
				"stock": 72,
				"grip": 84,
				"signature": 24
			},
			"materials": {
				"dark": true,
				"accent": true,
				"steel": true,
				"glow": true
			},
			"identity": {
				"id": 4,
				"short": "PLASMA",
				"receiver": "two rounded axial bulbs in a slab cradle",
				"feed": "power cell with a glowing plasma window",
				"muzzle": "projecting three-prong focus cage",
				"stock": "vented frame stock with cable runs",
				"sight": "iron sights on a short spine",
				"accent": "sky-blue plasma window and cable runs",
				"signature": "axial paired bulbs and round flank exchangers",
				"glow": true
			}
		}
	},
	{
		"id": 5,
		"name": "Grenade Launcher",
		"file": "weapon-5.glb",
		"sha256": "d67ec237651554deb9dea44ebef6704c6a026db11c3a40ea69413abbc1cd22ac",
		"bytes": 95944,
		"triangles": 2028,
		"draws": 4,
		"anchors": {
			"Muzzle": [
				0,
				0.04,
				-0.93
			],
			"WeaponGripLeft": [
				-0.14,
				-0.07,
				-0.2064
			],
			"WeaponGripRight": [
				0,
				-0.135,
				-0.035
			]
		},
		"bounds": [
			[
				-0.16050000488758087,
				-0.3020000159740448,
				-0.9300000071525574
			],
			[
				0.16050000488758087,
				0.1979999989271164,
				0.2280000001192093
			]
		],
		"detail": {
			"triangles": 1476,
			"zones": {
				"mount": 12,
				"sight": 156,
				"ejection": 60,
				"feed": 456,
				"heat": 132,
				"muzzle": 456,
				"stock": 72,
				"grip": 84,
				"signature": 48
			},
			"materials": {
				"dark": true,
				"accent": true,
				"steel": true,
				"glow": true
			},
			"identity": {
				"id": 5,
				"short": "GRENADE",
				"receiver": "squat revolver frame with a broad top strap",
				"feed": "flared six-flute revolver drum between support legs",
				"muzzle": "fat bore with a collar stack",
				"stock": "compact stock with a recoil pad",
				"sight": "iron sights with a ladder rear notch",
				"accent": "red-orange charge light and index marks",
				"signature": "flared slatted drum and top strap",
				"glow": true
			}
		}
	},
	{
		"id": 6,
		"name": "Shock Beam",
		"file": "weapon-6.glb",
		"sha256": "f23df962ea4aad5e05746afa32b2954b4d6acc345cb7f0c7beb7b43cd80121b1",
		"bytes": 78964,
		"triangles": 1416,
		"draws": 4,
		"anchors": {
			"Muzzle": [
				0,
				0,
				-0.99
			],
			"WeaponGripLeft": [
				-0.13,
				-0.105,
				-0.24
			],
			"WeaponGripRight": [
				0,
				-0.16999999999999998,
				-0.035
			]
		},
		"bounds": [
			[
				-0.1289999932050705,
				-0.2939999997615814,
				-1.0449999570846558
			],
			[
				0.1289999932050705,
				0.15799999237060547,
				0.18799999356269836
			]
		],
		"detail": {
			"triangles": 804,
			"zones": {
				"mount": 12,
				"sight": 108,
				"ejection": 84,
				"feed": 180,
				"heat": 120,
				"muzzle": 36,
				"stock": 60,
				"grip": 84,
				"signature": 120
			},
			"materials": {
				"dark": true,
				"accent": true,
				"steel": true,
				"glow": true
			},
			"identity": {
				"id": 6,
				"short": "SHOCK",
				"receiver": "square dorsal capacitor comb above the casing",
				"feed": "capacitor cell with vent slats",
				"muzzle": "wide projecting fork with discharge tips and tuning bridge",
				"stock": "open frame stock with a rear insulator stack",
				"sight": "iron sights on a short spine",
				"accent": "cyan arc bar between the prongs",
				"signature": "forward fork, bridge and capacitor comb",
				"glow": true
			}
		}
	},
	{
		"id": 7,
		"name": "Flak Cannon",
		"file": "weapon-7.glb",
		"sha256": "7b81b5b465ef7fb0b093d2254bd3e20f32a90ef660b2d4edb8732ea43bddf20b",
		"bytes": 89144,
		"triangles": 1804,
		"draws": 4,
		"anchors": {
			"Muzzle": [
				0,
				0,
				-0.99
			],
			"WeaponGripLeft": [
				-0.16,
				-0.125,
				-0.2448
			],
			"WeaponGripRight": [
				0,
				-0.19,
				-0.035
			]
		},
		"bounds": [
			[
				-0.19750000536441803,
				-0.3140000104904175,
				-1.0140000581741333
			],
			[
				0.1720000058412552,
				0.18700000643730164,
				0.21899999678134918
			]
		],
		"detail": {
			"triangles": 1192,
			"zones": {
				"mount": 12,
				"sight": 108,
				"ejection": 60,
				"feed": 204,
				"heat": 188,
				"muzzle": 240,
				"stock": 200,
				"grip": 84,
				"signature": 96
			},
			"materials": {
				"dark": true,
				"accent": true,
				"steel": true,
				"glow": true
			},
			"identity": {
				"id": 7,
				"short": "FLAK",
				"receiver": "boxy reinforced breech with trunnion discs",
				"feed": "ammunition box feed with a belt window",
				"muzzle": "heavy hollow flared bell",
				"stock": "thick shoulder stock with recoil springs",
				"sight": "iron sights beside an outboard carry handle",
				"accent": "amber belt rounds and chevrons",
				"signature": "box breech, flank handle and bell",
				"glow": false
			}
		}
	},
	{
		"id": 8,
		"name": "Marksman Rifle",
		"file": "weapon-8.glb",
		"sha256": "f21477aeb9a39a89d3b850d8aa0bdc467c7a726db496bc6dd3826ba7bc8ae2eb",
		"bytes": 101568,
		"triangles": 2028,
		"draws": 4,
		"anchors": {
			"Muzzle": [
				0,
				0.02,
				-0.84
			],
			"WeaponGripLeft": [
				-0.1,
				-0.06999999999999999,
				-0.2592
			],
			"WeaponGripRight": [
				0,
				-0.135,
				-0.035
			]
		},
		"bounds": [
			[
				-0.09849999845027924,
				-0.2590000033378601,
				-0.8400000333786011
			],
			[
				0.10999999940395355,
				0.24300000071525574,
				0.30000001192092896
			]
		],
		"detail": {
			"triangles": 1416,
			"zones": {
				"mount": 168,
				"sight": 528,
				"ejection": 60,
				"feed": 144,
				"heat": 120,
				"muzzle": 168,
				"stock": 60,
				"grip": 84,
				"signature": 84
			},
			"materials": {
				"dark": true,
				"accent": true,
				"steel": true,
				"glow": true
			},
			"identity": {
				"id": 8,
				"short": "MARKSMAN",
				"receiver": "long under-receiver precision chassis spine",
				"feed": "low-profile box magazine with a floorplate",
				"muzzle": "precision brake with three baffles",
				"stock": "adjustable cheek riser with a butt monopod",
				"sight": "large connected optic on a long rail",
				"accent": "warm-sand range dial and lens glint",
				"signature": "long spine, folded forward bipod and butt monopod",
				"glow": true
			}
		}
	},
	{
		"id": 9,
		"name": "Submachine Gun",
		"file": "weapon-9.glb",
		"sha256": "fdc556188e0b39ae51d9336a103e7a0c193af4f9db4939673865b651d2047c6a",
		"bytes": 86592,
		"triangles": 1632,
		"draws": 4,
		"anchors": {
			"Muzzle": [
				0,
				0.05,
				-0.835
			],
			"WeaponGripLeft": [
				-0.10500000000000001,
				-0.045,
				-0.16799999999999998
			],
			"WeaponGripRight": [
				0,
				-0.11,
				-0.035
			]
		},
		"bounds": [
			[
				-0.08799999952316284,
				-0.3479999899864197,
				-0.8349999785423279
			],
			[
				0.11500000208616257,
				0.17800000309944153,
				0.2980000078678131
			]
		],
		"detail": {
			"triangles": 1020,
			"zones": {
				"mount": 12,
				"sight": 156,
				"ejection": 100,
				"feed": 228,
				"heat": 144,
				"muzzle": 132,
				"stock": 128,
				"grip": 84,
				"signature": 36
			},
			"materials": {
				"dark": true,
				"accent": true,
				"steel": true,
				"glow": true
			},
			"identity": {
				"id": 9,
				"short": "SMG",
				"receiver": "stubby stamped receiver with a flank rear drum",
				"feed": "oversized quad-stack magazine hanging well below the receiver",
				"muzzle": "short open compensator",
				"stock": "extended twin-rod wire stock with a buttplate",
				"sight": "iron sights on a short spine",
				"accent": "mint charging handle and light module",
				"signature": "stub receiver, huge magazine and wire stock",
				"glow": false
			}
		}
	}
]
