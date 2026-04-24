// Sélection / création de la base
db = db.getSiblingDB("blog_db");

// Supprimer la collection si elle existe (optionnel pour tests)
db.posts.drop();

// Création de la collection avec validation JSON Schema
db.createCollection("posts", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["titre", "auteur", "vues"],
      properties: {
        titre: {
          bsonType: "string",
          description: "Le titre doit être une chaîne et est obligatoire"
        },
        auteur: {
          bsonType: "string",
          description: "L'auteur doit être une chaîne et est obligatoire"
        },
        vues: {
          bsonType: "int",
          description: "Les vues doivent être un entier et sont obligatoires"
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

// Insertion des données valides
db.posts.insertMany([
  {
    titre: "Introduction à MongoDB",
    auteur: "Alice",
    vues: 120
  },
  {
    titre: "Comprendre Node.js",
    auteur: "Bob",
    vues: 95
  },
  {
    titre: "Les bases de JavaScript",
    auteur: "Charlie",
    vues: 150
  },
  {
    titre: "Créer une API REST",
    auteur: "Diane",
    vues: 200
  },
  {
    titre: "Async/Await expliqué",
    auteur: "Eve",
    vues: 175
  }
]);

// Test : insertion invalide (doit échouer)
try {
  db.posts.insertOne({
    titre: "Erreur test",
    auteur: "Test",
    vues: "beaucoup" // ❌ invalide (string au lieu de int)
  });
} catch (e) {
  print("Insertion rejetée comme prévu :");
  print(e);
}

// Vérification
print("Documents dans la collection posts :");
db.posts.find().forEach(doc => printjson(doc));