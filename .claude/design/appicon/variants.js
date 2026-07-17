window.VARIANTS = {
  projectName: "FuelMap — App Icon",
  brandName: "FuelMap",
  concepts: [
    {
      name: "Finalistas — Colonnina € (gasolinera héroe + € = ahorro)",
      variants: [
        {
          id: "G2",
          name: "Bold + rejilla ★",
          description: "RECOMENDADO. Surtidor blanco sobre azure, display en cheapestGold, € en azure profundo. Máximo contraste y la rejilla conserva la mitad 'Map' del nombre.",
          light: "icon-colonnina-bold.svg"
        },
        {
          id: "G2f",
          name: "Bold plano",
          description: "Igual sin rejilla. Más limpio y premium, pero el icono pasa a decir solo 'Fuel': se pierde el mapa.",
          light: "icon-colonnina-bold-flat.svg"
        },
        {
          id: "G1",
          name: "Claro + rejilla",
          description: "Surtidor azure sobre suelo cartográfico claro (referencia Maps). Más sobrio; menos contraste global.",
          light: "icon-colonnina.svg"
        },
        {
          id: "G1f",
          name: "Claro plano",
          description: "Surtidor azure sobre fondo azul muy claro, sin rejilla.",
          light: "icon-colonnina-flat.svg"
        }
      ]
    },
    {
      name: "Ronda 4 — descartados",
      variants: [
        {
          id: "G3",
          name: "Pompa-pin ✗",
          description: "Surtidor terminado en punta de pin. La punta no lee como ubicación: lee como si el surtidor goteara. Mala imagen para una app de combustible.",
          light: "icon-pompa-pin.svg"
        }
      ]
    },
    {
      name: "Ronda 3 — solo € (faltaba la gasolinera)",
      variants: [
        {
          id: "N2a",
          name: "Euro claro ✗",
          description: "Pin azure con € en oro. Dice precio pero no dice combustible: valdría para cualquier app de precios.",
          light: "icon-euro-pin.svg"
        },
        {
          id: "N2b",
          name: "Euro oro ✗",
          description: "Pin en cheapestGold con € azure. Mismo problema, y el oro dominante puede leer 'taxi/aviso'.",
          light: "icon-euro-pin-bold.svg"
        },
        {
          id: "N1",
          name: "Livello ✗",
          description: "Pin como depósito, nivel bajo = precio bajo. Lee como indicador de carga a medias; a 40pt el oro es una astilla invisible.",
          light: "icon-livello.svg"
        },
        {
          id: "N3",
          name: "Costellazione ✗",
          description: "Pin oro entre estaciones azules. Funciona a 180pt; a 40pt los puntos son confeti.",
          light: "icon-costellazione.svg"
        },
        {
          id: "N4",
          name: "Due prezzi ✗",
          description: "Dos barras, gana la corta en oro. No dice precio: parece un skeleton loader.",
          light: "icon-due-prezzi.svg"
        }
      ]
    },
    {
      name: "Rondas 1-2 — descartados",
      variants: [
        {
          id: "02b",
          name: "Ribasso ✗",
          description: "Pin con el glifo ▼ (BASSO) calado revelando oro. Sólido en pequeño; descartado por decisión de producto.",
          light: "icon-ribasso-bold.svg"
        },
        {
          id: "01",
          name: "Totem-pin ✗",
          description: "El totem de precios de carretera como pin. Rasterizado lee como bocadillo de chat; estrecharlo lo empeoró.",
          light: "icon-totem.svg"
        },
        {
          id: "04",
          name: "F-pin ✗",
          description: "La F de FuelMap clavada en punta de pin. Se afina a 40pt y una F no dice ni precio ni mapa.",
          light: "icon-f-pin.svg"
        },
        {
          id: "05",
          name: "Cartellino ✗",
          description: "Etiqueta de precio con punta de pin. El azure translúcido sobre oro vira a verde oliva.",
          light: "icon-cartellino.svg"
        }
      ]
    }
  ]
};
