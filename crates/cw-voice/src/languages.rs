//! The languages the voice reads besides English, each a model of its own from
//! the same export as English's (`KevinAHM/pocket-tts-onnx`, `MODEL_AT`), in
//! its folder `onnx/<source>`, downloaded when the user picks it on Settings ›
//! Voices and kept in the voice's folder under its `id`. French is only there
//! as the larger model (24 layers, about 390 MB); the others are about 165 MB.
//! A language is told by its code as the setting "Language the AI writes in"
//! keeps it (`languages.rs`). The voices' recordings serve every language.

/// A language the voice can read in, and the files of its model: name, size
/// in bytes and SHA-256, as the export's listing gives them.
pub struct Language {
    pub id: &'static str,
    pub name: &'static str,
    pub code: &'static str,
    pub source: &'static str,
    pub files: &'static [(&'static str, u64, &'static str)],
}

pub const LANGUAGES: &[Language] = &[
    Language {
        id: "german",
        name: "German",
        code: "de",
        source: "german",
        files: &[
            (
                "bundle.json",
                24_362,
                "7f032e4df0db3a02e24871dfa496e2b7ffa095dd98640bfcf12c04b8671ac60e",
            ),
            (
                "tokenizer.model",
                59_837,
                "389079b9c67cd17ff1c565d53bc695df390b4ca8abf2300947e659585edd9d2a",
            ),
            (
                "bos_before_voice.npy",
                4_224,
                "8c866aec4bcd5f0e6ca788f4b24eacba799b02262905e9f5d6f967409872f8df",
            ),
            (
                "text_conditioner.onnx",
                16_388_344,
                "a004c74047bc1c4208f6ca150c6337fb541ab03e154493f456d43baa0fd469f1",
            ),
            (
                "mimi_encoder.onnx",
                39_768_446,
                "71a00b2c6270af5f99389609bcd3d4682bf692fccb8f0ff9b21c3d2e473a204b",
            ),
            (
                "flow_lm_main_int8.onnx",
                76_341_079,
                "3d5e9cd303ecd26fc75b91e2766bce6de3d274d397d3ee9a392f6299366681ef",
            ),
            (
                "flow_lm_flow_int8.onnx",
                9_962_530,
                "2b0eb8381c49672ac1050c50221db02033b5dc6c346ab45c67bd05344257f06c",
            ),
            (
                "mimi_decoder_int8.onnx",
                22_684_077,
                "3fe868810d66fa0c26bb3ae0d5ee65cae83028c0fe83398bcf3d96478f68083b",
            ),
        ],
    },
    Language {
        id: "italian",
        name: "Italian",
        code: "it",
        source: "italian",
        files: &[
            (
                "bundle.json",
                24_365,
                "c779c25fd836c9b85a3fc570474774777176757bd6bec0b5bffbbe599644a9f9",
            ),
            (
                "tokenizer.model",
                60_078,
                "6583b974a11b90e14d8a4c8e9c43f06c3861b9ede6e5023a4c27ab5a3a7d4c39",
            ),
            (
                "bos_before_voice.npy",
                4_224,
                "212357ca66b450e7dc2ae6cb11f1efd08b49c59e25196a6979c37962fef6cd82",
            ),
            (
                "text_conditioner.onnx",
                16_388_344,
                "692369f5ac340006fa44252155da77fe6c8a60a859848297777e0caea534068e",
            ),
            (
                "mimi_encoder.onnx",
                39_768_446,
                "8936e1f95baedb898941fc7a259d7ab8c031aeaf6d3746ecac3cf7b280a9adda",
            ),
            (
                "flow_lm_main_int8.onnx",
                76_341_079,
                "f43ce4d823471095a7bd6d9dcfcceb46145ea96b0f2b85b7d668f15816965055",
            ),
            (
                "flow_lm_flow_int8.onnx",
                9_962_530,
                "21b2bec2f9ae4323fc545a0c7ffb274bdfa925a699fd304ed03aba53e4ca9129",
            ),
            (
                "mimi_decoder_int8.onnx",
                22_684_077,
                "f120bc5cddca9514c511f128786f5d9e6e6893b067faae5e30f5b2bd5643aa03",
            ),
        ],
    },
    Language {
        id: "portuguese",
        name: "Portuguese",
        code: "pt",
        source: "portuguese",
        files: &[
            (
                "bundle.json",
                24_371,
                "389ab9d942f044a6a71d04e86ba89b100dee21ed91ca9d099b19ac45b122d242",
            ),
            (
                "tokenizer.model",
                60_995,
                "3aa51309c55f114771c156aaeb86f6fc325991364aa3c38af74aecf1cbd0fade",
            ),
            (
                "bos_before_voice.npy",
                4_224,
                "9396378d581d63554cc30f2861e5d5b825650ff3dd3594a9ddc73d18df0973f1",
            ),
            (
                "text_conditioner.onnx",
                16_388_344,
                "693523a9b8e8853a7130676fd0e8189939255411700f0207664715226a26c409",
            ),
            (
                "mimi_encoder.onnx",
                39_768_446,
                "189d737f150a3d72be0818235c2b42f921cb1ad39107d11bb2e7f605fbdc7bc5",
            ),
            (
                "flow_lm_main_int8.onnx",
                76_341_079,
                "119e5ce926cadc273508565143c86a7a9cd86450fa99cad6a37a79ba50f9db02",
            ),
            (
                "flow_lm_flow_int8.onnx",
                9_962_530,
                "53c50fc75f892687920c316513715bfbefbdb3b7642786e287c7971df53edb26",
            ),
            (
                "mimi_decoder_int8.onnx",
                22_684_077,
                "691f89f074585c828914cecd5396e30e0e2a14dbfa4890bd1b5806d303daeb4e",
            ),
        ],
    },
    Language {
        id: "spanish",
        name: "Spanish",
        code: "es",
        source: "spanish",
        files: &[
            (
                "bundle.json",
                24_365,
                "c9f18b5fc326c2a99f645588b79ef27ef3c9c6c3066f8df73bccb7f7c1f855b3",
            ),
            (
                "tokenizer.model",
                60_895,
                "aac2b96478e3e3068712bd5c45dc196f84b7341ea72587c33a2094957f0c1b0c",
            ),
            (
                "bos_before_voice.npy",
                4_224,
                "2c77a716ac206316d6656bdb4cf09e8a2fc9fa7a7f6cde4cceadc3fd7bb1d2a1",
            ),
            (
                "text_conditioner.onnx",
                16_388_344,
                "836ad5231fffe6d8fd23c8340d6d91676f466cd35057afd06b7db6ab69baae11",
            ),
            (
                "mimi_encoder.onnx",
                39_768_446,
                "6702fb117c58ff1f486f0b5153cafa41bca3811f08c560cc857ba445dd98a614",
            ),
            (
                "flow_lm_main_int8.onnx",
                76_341_079,
                "9b020318976e0437bcc78ad0f4a49bf1de6e6e2193c6b0380398038601f9a270",
            ),
            (
                "flow_lm_flow_int8.onnx",
                9_962_530,
                "4cc630a8fc1d28e3b432349e492f5f81696aab88b1067b5282b15427fde19efe",
            ),
            (
                "mimi_decoder_int8.onnx",
                22_684_077,
                "309efd11b65c58cd176e554d09241f3e2c9aaabd8cbf74b8f01bdd3ec8f7d8e5",
            ),
        ],
    },
    Language {
        id: "french",
        name: "French",
        code: "fr",
        source: "french_24l",
        files: &[
            (
                "bundle.json",
                42_235,
                "8a5fe6c59985e3ccb5a6ccb1ffb2e84ac08488c5bfa704053618851436741427",
            ),
            (
                "tokenizer.model",
                60_173,
                "521c85bdb2da10618f4be52021ed1cb2a7a6299b040708487f133193f7b305e2",
            ),
            (
                "bos_before_voice.npy",
                4_224,
                "5759269802d691d49481b8e06d6a5649da85ea01135e270bd7641e3b091c7237",
            ),
            (
                "text_conditioner.onnx",
                16_388_344,
                "89d1b6ac55e618e42d2bd840438ce918bffb14960475ef091847ca39be641e65",
            ),
            (
                "mimi_encoder.onnx",
                39_768_446,
                "790a82fb8041e1035ec8097c6a277c834664a1f6619397d62f3bb46f71d2bfd4",
            ),
            (
                "flow_lm_main_int8.onnx",
                305_144_125,
                "6130a6b98fae175147d82752263e250fb7b8483c1ef5373753ad335c16f4a129",
            ),
            (
                "flow_lm_flow_int8.onnx",
                9_962_530,
                "d340c549d5a1e0e7b88a0fb26fcae53c3b76486872f4418398a395bb1bc88701",
            ),
            (
                "mimi_decoder_int8.onnx",
                22_684_077,
                "b329ff3de3aa95455d2dee1cf371943dec269dd8711008017501ca129cb18d8c",
            ),
        ],
    },
];
