curl -X POST http://loud-meadow-alb-235533752.eu-west-1.elb.amazonaws.com/transcribe \
  -H "x-api-key: e20ce61a459e49ed9319ceab0f72b5d1" \
  -F "audio=@/Users/raer/Documents/code/ncapi/stuff/sagemaker-whisper/whisper-secret-standard/b.mp3"
