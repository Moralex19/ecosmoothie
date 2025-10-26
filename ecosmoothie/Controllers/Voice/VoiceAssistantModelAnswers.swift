//
//  VoiceAssistantModelAnswers.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 25/10/25.
//

import Foundation

extension VoiceAssistantViewModel {
    func makeAnswer(from query: String) -> String {
        let q = query.folding(options: [.diacriticInsensitive, .caseInsensitive],
                              locale: .current)
                     .lowercased()
                     .trimmingCharacters(in: .whitespacesAndNewlines)

        if containsAll(q, ["durazno", "beneficio"]) || containsAll(q, ["smoothie de durazno", "beneficio"]) {
            return """
            El durazno es rico en vitaminas C y A y en fibra: mejora la digestión, fortalece el sistema inmunológico y ayuda a mantener la piel sana.
            """
        }
        if containsAll(q, ["durazno", "piel"]) {
            return """
            Gracias a sus antioxidantes y betacarotenos, el durazno combate radicales libres y ayuda a retrasar el envejecimiento prematuro de la piel.
            """
        }
        if containsAll(q, ["durazno", "verano"]) || containsAll(q, ["durazno", "hidrata"]) {
            return """
            Ideal en verano: alto contenido de agua, hidratante y refrescante; ayuda a prevenir la deshidratación.
            """
        }
        if containsAll(q, ["durazno", "momento"]) || containsAll(q, ["durazno", "cuando"]) {
            return """
            Mejor horario: media mañana o tarde poscomida. Como pre-entreno, añade avena o yogur para energía sostenida.
            """
        }
        if containsAll(q, ["durazno", "hierro"]) || containsAll(q, ["durazno", "potenciar"]) {
            return """
            Combínalo con espinaca o avena: la vitamina C del durazno mejora la absorción del hierro vegetal.
            """
        }
        if containsAll(q, ["durazno", "azucar"]) || containsAll(q, ["durazno", "dulce"]) {
            return """
            El durazno aporta azúcares naturales y dulzor propio; no necesita azúcar refinada.
            """
        }
        if containsAll(q, ["durazno", "dieta"]) || containsAll(q, ["durazno", "bajas calorias"]) {
            return """
            Sí: es bajo en calorías y alto en agua, ideal para hidratarte sin aumentar de peso.
            """
        }

        // === KIWI ===
        if containsAll(q, ["kiwi", "beneficio"]) {
            return """
            El kiwi tiene más vitamina C que una naranja; potencia defensas y estimula la producción de colágeno.
            """
        }
        if containsAll(q, ["kiwi", "digest"]) || containsAll(q, ["kiwi", "intestin"]) {
            return """
            Aporta actinidina, una enzima que facilita la digestión de proteínas y mejora el tránsito intestinal.
            """
        }
        if containsAll(q, ["kiwi", "deport"]) {
            return """
            Sí: aporta potasio y magnesio, útiles para recuperación y para evitar calambres musculares.
            """
        }
        if containsAll(q, ["kiwi", "destaca"]) || containsAll(q, ["kiwi", "que tiene"]) {
            return """
            Destaca por vitamina C altísima, actinidina (enzima digestiva), potasio y fibra.
            """
        }
        if containsAll(q, ["kiwi", "niñ"]) || containsAll(q, ["kiwi", "ninos"]) {
            return """
            Recomendable para niñas y niños: gran fuente de vitaminas y apoyo al sistema inmunológico.
            """
        }

        // === MANGO ===
        if containsAll(q, ["mango", "superfruta"]) || containsAll(q, ["mango", "super fruta"]) {
            return """
            El mango es una “superfruta” por su aporte de vitaminas A, C y E y antioxidantes que protegen el corazón y la vista.
            """
        }
        if containsAll(q, ["mango", "estado de animo"]) || containsAll(q, ["mango", "serotonina"]) || containsAll(q, ["mango", "estres"]) {
            return """
            El mango estimula la serotonina: ayuda a reducir el estrés y a mejorar el estado de ánimo.
            """
        }
        if containsAll(q, ["mango", "beneficio"]) && !q.contains("principal") {
            return """
            Aporta vitaminas A, C, E, B6, y minerales como cobre y potasio. Antioxidantes: mangiferina, quercetina y astragalina.
            """
        }
        if containsAll(q, ["mango", "principal"]) || containsAll(q, ["mango", "beneficios principales"]) {
            return """
            • 👁️ Vista: la vitamina A previene la ceguera nocturna.
            • ❤️ Corazón: ayuda a controlar triglicéridos y colesterol.
            • 💆 Digestión: enzimas que descomponen proteínas.
            • 😊 Ánimo: favorece la serotonina, reduce ansiedad y estrés.
            • 💦 Hidratación: refresca tras ejercicio o en clima cálido.
            """
        }
        if containsAll(q, ["mango", "mañana"]) || containsAll(q, ["mango", "manana"]) || containsAll(q, ["mango", "desayuno"]) {
            return """
            En la mañana te da energía natural, mejora concentración y activa el metabolismo.
            """
        }

        // === FRESA ===
        if containsAll(q, ["fresa", "contien"]) || containsAll(q, ["fresa", "que tiene"]) {
            return """
            Ricas en vitamina C, fibra, manganeso y antioxidantes (antocianinas). Contienen ácido elágico con potencial anticancerígeno.
            """
        }
        if containsAll(q, ["fresa", "beneficio"]) || containsAll(q, ["fresa", "para que sirve"]) {
            return """
            • 💖 Corazón: reduce colesterol y mejora salud arterial.
            • 🧠 Cognición: flavonoides favorecen memoria y concentración.
            • 🩸 Glucosa: su fibra ralentiza la absorción de azúcar.
            • 💄 Piel: antioxidantes combaten radicales libres.
            • ⚖️ Peso: bajas en calorías y saciantes.
            """
        }

        // === CAFÉ ===
        if containsAll(q, ["cafe", "beneficio"]) || containsAll(q, ["smoothie de cafe", "beneficio"]) {
            return """
            Aporta energía inmediata, mejora la concentración y estimula el metabolismo, ayudando a quemar grasas.
            """
        }
        if containsAll(q, ["cafe", "saludable"]) || containsAll(q, ["cafe", "solo"]) || containsAll(q, ["cafe", "acidez"]) {
            return """
            En smoothie puede ser más balanceado: con leche vegetal, plátano o avena resulta menos ácido e ideal como pre-entreno.
            """
        }
        if containsAll(q, ["cafe", "antioxid"]) {
            return """
            Sí: el café es una de las principales fuentes de antioxidantes naturales; ayuda a prevenir el envejecimiento celular.
            """
        }
        if containsAll(q, ["cafe", "mas saludable"]) || containsAll(q, ["cafe", "como hacerlo"]) {
            return """
            Hazlo más saludable usando leche vegetal, plátano, avena o miel natural en lugar de azúcar refinada.
            """
        }
        if containsAll(q, ["cafe", "como las frutas"]) && q.contains("antioxid") {
            return """
            ¡Sí! El café es de las bebidas más ricas en antioxidantes naturales del mundo.
            """
        }

        // === BENEFICIOS COMBINADOS / GENERALES ===
        if containsAll(q, ["smoothie", "mejores", "jugos"]) || containsAll(q, ["por que", "smoothie", "jugos"]) {
            return """
            Los smoothies naturales conservan toda la fibra, vitaminas y enzimas de la fruta, sin azúcar añadida; a diferencia de muchos jugos procesados.
            """
        }
        if containsAll(q, ["combino", "mango"]) && containsAny(q, ["fresa", "kiwi"]) {
            return """
            Mezclar mango con fresa y/o kiwi te da un cóctel de vitaminas A, C y E: fortalece defensas y aporta energía natural.
            """
        }
        if containsAll(q, ["deport", "smoothie"]) || containsAll(q, ["ejercicio", "smoothie"]) {
            return """
            Recomendables para deportistas: ayudan a recuperar energía, hidratarse y reponer electrolitos tras el ejercicio.
            """
        }
        if containsAll(q, ["piel", "cabello"]) || containsAll(q, ["cabello", "smoothie"]) {
            return """
            Antioxidantes y vitaminas mejoran la elasticidad de la piel, el brillo del cabello y previenen el envejecimiento prematuro.
            """
        }
        if containsAll(q, ["mejor hora", "smoothie"]) || containsAll(q, ["cuando", "tomar", "smoothie"]) {
            return """
            En la mañana o después de entrenar: el cuerpo aprovecha mejor los nutrientes y la energía.
            """
        }
        if containsAll(q, ["mas saludable", "menu"]) || containsAll(q, ["cual", "mas saludable"]) {
            return """
            Depende del objetivo:
            • Energía → Mango o Café
            • Defensas → Kiwi o Fresa
            """
        }
        if containsAll(q, ["sin azucar"]) || containsAll(q, ["azucar anadida"]) || containsAll(q, ["azucar añadida"]) {
            return """
            ¡Claro! Podemos prepararlos solo con el dulzor natural de la fruta o usar miel orgánica.
            """
        }
        if containsAll(q, ["cuantas veces", "semana"]) || containsAll(q, ["frecuencia", "smoothie"]) {
            return """
            Ideal de 3 a 5 veces por semana, como parte de una dieta equilibrada.
            """
        }
        if containsAll(q, ["combinar", "frutas"]) || containsAll(q, ["varias frutas", "uno"]) {
            return """
            Sí: mezclar frutas potencia beneficios y mejora el sabor.
            """
        }
        if containsAll(q, ["naturales", "industriales"]) || containsAll(q, ["por que", "mejores", "industriales"]) {
            return """
            Los smoothies naturales mantienen la fibra, vitaminas y enzimas vivas, sin conservadores ni azúcares procesados.
            """
        }

        // === RESPUESTAS RÁPIDAS POR FRUTA (fallback) ===
        if q.contains("durazno") {
            return "Smoothie de durazno: vitaminas C y A, fibra e hidratación; bueno para digestión, defensas y piel."
        }
        if q.contains("kiwi") {
            return "Smoothie de kiwi: vitamina C muy alta, actinidina digestiva, potasio y fibra; ideal para defensas y deportistas."
        }
        if q.contains("mango") {
            return "Smoothie de mango: vitaminas A/C/E, enzimas digestivas y antioxidantes; apoya vista, corazón y estado de ánimo."
        }
        if q.contains("fresa") {
            return "Smoothie de fresa: vitamina C, fibra y antocianinas; corazón, control de glucosa, piel y saciedad."
        }
        if q.contains("cafe") || q.contains("café") {
            return "Smoothie de café: energía y enfoque; con leche vegetal/avena/plátano es más balanceado y menos ácido."
        }

        return "Puedo contarte beneficios de smoothies de durazno, kiwi, mango, fresa o café; o recomendarte combinaciones según tu objetivo. ¿Cuál te interesa?"
        
    }
}

// Helpers
func containsAll(_ text: String, _ terms: [String]) -> Bool { terms.allSatisfy { text.contains($0) } }
func containsAny(_ text: String, _ terms: [String]) -> Bool { terms.contains(where: { text.contains($0) }) }

