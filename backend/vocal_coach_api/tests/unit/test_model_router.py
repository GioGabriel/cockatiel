from app.ai_engine.model_router.service import OllamaModelRouter


def test_model_router_deduplicates_and_trims_models():
  router = OllamaModelRouter([" qwen2.5:7b ", "qwen2.5:7b", "", "llama3.1:8b"])
  assert router.candidates() == ("qwen2.5:7b", "llama3.1:8b")
