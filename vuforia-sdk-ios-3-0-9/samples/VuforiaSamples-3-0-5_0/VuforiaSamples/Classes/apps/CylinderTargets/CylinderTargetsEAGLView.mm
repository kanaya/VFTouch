/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <sys/time.h>

#import <QCAR/QCAR.h>
#import <QCAR/State.h>
#import <QCAR/Tool.h>
#import <QCAR/Renderer.h>
#import <QCAR/TrackableResult.h>
#import <QCAR/VideoBackgroundConfig.h>

#import "CylinderTargetsEAGLView.h"
#import "Texture.h"
#import "SampleApplicationUtils.h"
#import "SampleApplicationShaderUtils.h"
#import "SoccerballSphere.h"
#import "Teapot.h"
#import "Capsule.h"

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#endif

//******************************************************************************
// *** OpenGL ES thread safety ***
//
// OpenGL ES on iOS is not thread safe.  We ensure thread safety by following
// this procedure:
// 1) Create the OpenGL ES context on the main thread.
// 2) Start the QCAR camera, which causes QCAR to locate our EAGLView and start
//    the render thread.
// 3) QCAR calls our renderFrameQCAR method periodically on the render thread.
//    The first time this happens, the defaultFramebuffer does not exist, so it
//    is created with a call to createFramebuffer.  createFramebuffer is called
//    on the main thread in order to safely allocate the OpenGL ES storage,
//    which is shared with the drawable layer.  The render (background) thread
//    is blocked during the call to createFramebuffer, thus ensuring no
//    concurrent use of the OpenGL ES context.
//
//******************************************************************************


namespace {
    // --- Data private to this unit ---

    // Texture filenames
    const char* textureFilenames[NUM_AUGMENTATION_TEXTURES] = {
        "TextureTransparent.png",
        "TextureSoccerBall.png",
        "TextureTeapotBrass.png",
        "TextureTeapotBlue.png"
    };
    
    enum tagAugmentationTextureIndex {
        CYLINDER_TEXTURE_INDEX,
        BALL_TEXTURE_INDEX
    };
    
    // --- Cylinder ---
    // Dimensions of the cylinder (as set in the TMS tool)
    const float kCylinderHeight = 82.0f;
    const float kCylinderTopDiameter = 65.0f * 82.0f / 95.0f;
    const float kCylinderBottomDiameter = 65.0f * 82.0f / 95.0f;
    
    // Ratio between top and bottom diameter, used to generate the cylinder
    // model
    const float kCylinderTopRadiusRatio = kCylinderTopDiameter / kCylinderBottomDiameter;
    
    // Model scale factor (scaled to fit the actual cylinder)
    const float kCylinderScaleX = kCylinderBottomDiameter / 2.0;
    const float kCylinderScaleY = kCylinderBottomDiameter / 2.0;
    const float kCylinderScaleZ = kCylinderHeight;
    
    
    // --- Soccer ball ---
    // Make the ball 1/3 of the height of the cylinder
    const float kRatioBallHeight = 1.0f;
    const float kRatioCylinderHeight = 3.0f;
    
    // Augmentation model scale factor
    const float kBallObjectScale = kCylinderHeight / (kRatioCylinderHeight * kRatioBallHeight);
    
    // Model scale factor
    const float kObjectScaleNormal = 10.0f;
}

GLfloat cubeVertices[] =
{
    -5,  5,  5,  5, -5,  5,  5,  5,  5, -5, -5,  5,
    -5,  5, -5,  5, -5, -5,  5,  5, -5, -5, -5, -5,
    -5, -5,  5,  5, -5, -5,  5, -5,  5, -5, -5, -5,
    -5,  5,  5,  5,  5, -5,  5,  5,  5, -5,  5, -5,
     5, -5,  5,  5,  5, -5,  5,  5,  5,  5, -5, -5,
    -5, -5,  5, -5,  5, -5, -5,  5,  5, -5, -5, -5
};

GLfloat cubeNormals[] =
{
     0,  0,  1,  0,  0,  1,  0,  0,  1,  0,  0,  1,
     0,  0, -1,  0,  0, -1,  0,  0, -1,  0,  0, -1,
     0, -1,  0,  0, -1,  0,  0, -1,  0,  0, -1,  0,
     0,  1,  0,  0,  1,  0,  0,  1,  0,  0,  1,  0,
     1,  0,  0,  1,  0,  0,  1,  0,  0,  1,  0,  0,
    -1,  0,  0, -1,  0,  0, -1,  0,  0, -1,  0,  0
};

//GLbyte cubeIndices[] =
//{
//    0, 1, 2, 3,
//    5, 0, 3, 4,
//    5, 6, 7, 4,
//    5, 6, 1, 0,
//    1, 6, 7, 2,
//    7, 4, 3, 2,
//};

GLbyte cubeIndices[] =
{
    0, 3, 1, 2, 0, 1,
    6, 5, 4, 5, 7, 4,
    8,11, 9,10, 8, 9,
    15,12,13,12,14,13,
    16,19,17,18,16,17,
    23,20,21,20,22,21
};

// cube
#define cube_vertexcount 	24
#define cube_polygoncount 	12

float cube_vertex[cube_vertexcount][8]={
    {0.00000, 1.00000, 0.00000, 0.00000, 1.00000, -0.50000, 0.00000, 0.50000},
    {0.00000, 0.00000, 0.00000, 0.00000, 1.00000, -0.50000, 1.00000, 0.50000},
    {1.00000, 0.00000, 0.00000, 0.00000, 1.00000, 0.50000, 1.00000, 0.50000},
    {1.00000, 1.00000, 0.00000, 0.00000, 1.00000, 0.50000, 0.00000, 0.50000},
    {0.00000, 1.00000, 0.00000, 0.00000, -1.00000, 0.50000, 0.00000, -0.50000},
    {0.00000, 0.00000, 0.00000, 0.00000, -1.00000, 0.50000, 1.00000, -0.50000},
    {1.00000, 0.00000, 0.00000, 0.00000, -1.00000, -0.50000, 1.00000, -0.50000},
    {1.00000, 1.00000, 0.00000, 0.00000, -1.00000, -0.50000, 0.00000, -0.50000},
    {0.00000, 1.00000, -1.00000, 0.00000, 0.00000, -0.50000, 0.00000, -0.50000},
    {0.00000, 0.00000, -1.00000, 0.00000, 0.00000, -0.50000, 1.00000, -0.50000},
    {1.00000, 0.00000, -1.00000, 0.00000, 0.00000, -0.50000, 1.00000, 0.50000},
    {1.00000, 1.00000, -1.00000, 0.00000, 0.00000, -0.50000, 0.00000, 0.50000},
    {0.00000, 1.00000, 1.00000, 0.00000, 0.00000, 0.50000, 0.00000, 0.50000},
    {0.00000, 0.00000, 1.00000, 0.00000, 0.00000, 0.50000, 1.00000, 0.50000},
    {1.00000, 0.00000, 1.00000, 0.00000, 0.00000, 0.50000, 1.00000, -0.50000},
    {1.00000, 1.00000, 1.00000, 0.00000, 0.00000, 0.50000, 0.00000, -0.50000},
    {0.00000, 1.00000, 0.00000, 1.00000, 0.00000, -0.50000, 1.00000, 0.50000},
    {0.00000, 0.00000, 0.00000, 1.00000, 0.00000, -0.50000, 1.00000, -0.50000},
    {1.00000, 0.00000, 0.00000, 1.00000, 0.00000, 0.50000, 1.00000, -0.50000},
    {1.00000, 1.00000, 0.00000, 1.00000, 0.00000, 0.50000, 1.00000, 0.50000},
    {0.00000, 1.00000, 0.00000, -1.00000, 0.00000, -0.50000, 0.00000, -0.50000},
    {0.00000, 0.00000, 0.00000, -1.00000, 0.00000, -0.50000, 0.00000, 0.50000},
    {1.00000, 0.00000, 0.00000, -1.00000, 0.00000, 0.50000, 0.00000, 0.50000},
    {1.00000, 1.00000, 0.00000, -1.00000, 0.00000, 0.50000, 0.00000, -0.50000},
};


unsigned short cube_index[cube_polygoncount][3]={
    {0, 1, 2},
    {2, 3, 0},
    {4, 5, 6},
    {6, 7, 4},
    {8, 9, 10},
    {10, 11, 8},
    {12, 13, 14},
    {14, 15, 12},
    {16, 17, 18},
    {18, 19, 16},
    {20, 21, 22},
    {22, 23, 20},
};

// ebuc

@interface CylinderTargetsEAGLView (PrivateMethods)

- (void)initShaders;
- (void)createFramebuffer;
- (void)deleteFramebuffer;
- (void)setFramebuffer;
- (BOOL)presentFramebuffer;

@end


@implementation CylinderTargetsEAGLView

// You must implement this method, which ensures the view's underlying layer is
// of type CAEAGLLayer
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}


//------------------------------------------------------------------------------
#pragma mark - Lifecycle

- (id)initWithFrame:(CGRect)frame appSession:(SampleApplicationSession *) app
{
    self = [super initWithFrame:frame];
    
    if (self) {
        vapp = app;
        // Enable retina mode if available on this device
        if (YES == [vapp isRetinaDisplay]) {
            [self setContentScaleFactor:2.0f];
        }
        
        // Load the augmentation textures
        for (int i = 0; i < NUM_AUGMENTATION_TEXTURES; ++i) {
            augmentationTexture[i] = [[Texture alloc] initWithImageFile:[NSString stringWithCString:textureFilenames[i] encoding:NSASCIIStringEncoding]];
        }

        // Create the OpenGL ES context
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        // The EAGLContext must be set for each thread that wishes to use it.
        // Set it the first time this method is called (on the main thread)
        if (context != [EAGLContext currentContext]) {
            [EAGLContext setCurrentContext:context];
        }
        
        // Generate the OpenGL ES texture and upload the texture data for use
        // when rendering the augmentation
        for (int i = 0; i < NUM_AUGMENTATION_TEXTURES; ++i) {
            GLuint textureID;
            glGenTextures(1, &textureID);
            [augmentationTexture[i] setTextureID:textureID];
            glBindTexture(GL_TEXTURE_2D, textureID);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, [augmentationTexture[i] width], [augmentationTexture[i] height], 0, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid*)[augmentationTexture[i] pngData]);
        }
        
        // Instantiate the cylinder model
        cylinderModel = new CylinderModel(kCylinderTopRadiusRatio);
        offTargetTrackingEnabled = NO;
        
        [self initShaders];
        
        drawLine = [[NSMutableArray alloc] init];
        drawLines = [[NSMutableArray alloc] init];
        [self clearDrawLines];
    }
    
    return self;
}


- (void)dealloc
{
    [self deleteFramebuffer];
    
    // Tear down context
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    [context release];

    for (int i = 0; i < NUM_AUGMENTATION_TEXTURES; ++i) {
        [augmentationTexture[i] release];
    }

    [super dealloc];
}


- (void)finishOpenGLESCommands
{
    // Called in response to applicationWillResignActive.  The render loop has
    // been stopped, so we now make sure all OpenGL ES commands complete before
    // we (potentially) go into the background
    if (context) {
        [EAGLContext setCurrentContext:context];
        glFinish();
    }
}


- (void)freeOpenGLESResources
{
    // Called in response to applicationDidEnterBackground.  Free easily
    // recreated OpenGL ES resources
    [self deleteFramebuffer];
    glFinish();
}

- (void) setOffTargetTrackingMode:(BOOL) enabled {
    offTargetTrackingEnabled = enabled;
}
    
//------------------------------------------------------------------------------
#pragma mark - UIGLViewProtocol methods

// Draw the current frame using OpenGL
//
// This method is called by QCAR when it wishes to render the current frame to
// the screen.
//
// *** QCAR will call this method periodically on a background thread ***
- (void)renderFrameQCAR
{
    [self setFramebuffer];
    
    // Clear colour and depth buffers
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Begin QCAR rendering for this frame, retrieving the tracking state
    QCAR::State state = QCAR::Renderer::getInstance().begin();
    
    // Render the video background
    QCAR::Renderer::getInstance().drawVideoBackground();
    
    glEnable(GL_DEPTH_TEST);
    // We must detect if background reflection is active and adjust the culling direction.
    // If the reflection is active, this means the pose matrix has been reflected as well,
    // therefore standard counter clockwise face culling will result in "inside out" models.
//    glEnable(GL_CULL_FACE);
    
    glCullFace(GL_BACK);
    if(QCAR::Renderer::getInstance().getVideoBackgroundConfig().mReflection == QCAR::VIDEO_BACKGROUND_REFLECTION_ON)
        glFrontFace(GL_CW);  //Front camera
    else
        glFrontFace(GL_CCW);   //Back camera
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    float pentip[] = {-kCylinderTopDiameter / 2.0f + 10.0f, 0.0f, -kCylinderHeight + 4.0f, 1.0f};
    cv::Mat pentipMat(4, 1, CV_32FC1, pentip);
    cv::Mat pen2world(4, 4, CV_32FC1);
    cv::Mat target2world(4, 4, CV_32FC1);
    int flagDetectBoth = 0;
    QCAR::Matrix44F targetModelViewMatrix;

    for (int i = 0; i < state.getNumTrackableResults(); ++i) {
        glUseProgram(shaderProgramID);
        
        // Get the trackable
        const QCAR::TrackableResult* result = state.getTrackableResult(i);
        const QCAR::Trackable& trackable = result->getTrackable();

        // Choose the texture based on the target name
        int targetIndex = 0; // "cylinder"
        if (!strcmp(trackable.getName(), "stones"))
            targetIndex = 1;
        else if (!strcmp(trackable.getName(), "chips"))
            targetIndex = 2;

        
        if (targetIndex == 0) // Cylinder
        {
            // Enable vertex, normal and texture coordinate arrays
            glEnableVertexAttribArray(vertexHandle);
            glEnableVertexAttribArray(normalHandle);
            glEnableVertexAttribArray(textureCoordHandle);
            
            
            QCAR::Matrix44F modelViewProjection;
            
            // --- Cylinder augmentation ---
            // The cylinder's texture is a transparent image; we draw it to obscure
            // the soccer ball, rather than to actually render it to the screen
            QCAR::Matrix44F modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(result->getPose());
            
            // Scale the model, then apply the projection matrix
            
            SampleApplicationUtils::scalePoseMatrix(kCylinderScaleX, kCylinderScaleY, kCylinderScaleZ, &modelViewMatrix.data[0]);
            SampleApplicationUtils::multiplyMatrix(&vapp.projectionMatrix.data[0], &modelViewMatrix.data[0], &modelViewProjection.data[0]);
            
            
            // Set the vertex attribute pointers
            
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)cylinderModel->ptrVertices());
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)cylinderModel->ptrNormals());
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)cylinderModel->ptrTexCoords());
            
            
            // Set the active texture unit
            glActiveTexture(GL_TEXTURE0);
            glUniform1i(texSampler2DHandle, 0);
            
            // Bind the texture and draw the geometry
            
            glBindTexture(GL_TEXTURE_2D, [augmentationTexture[CYLINDER_TEXTURE_INDEX] textureID]);
            
            
            glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE, (const GLfloat*)&modelViewProjection.data[0] );
            
            glDrawElements(GL_TRIANGLES, cylinderModel->nbIndices(), GL_UNSIGNED_SHORT, (const GLvoid*)cylinderModel->ptrIndices());
            // --- End of cylinder augmentation ---
            
            /*
            // Calculate the position of the ball at the current time
            // --- Soccer ball augmentation ---
            modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(result->getPose());
            
            //        [self animateObject:modelViewMatrix];
            
            // Translate and scale the model, then apply the projection matrix
            //        SampleApplicationUtils::translatePoseMatrix(1.0f * kCylinderTopDiameter, 0.0f, kBallObjectScale, &modelViewMatrix.data[0]);
            SampleApplicationUtils::translatePoseMatrix(0.0f, 0.0f, kCylinderHeight, &modelViewMatrix.data[0]);
            SampleApplicationUtils::scalePoseMatrix(kBallObjectScale, kBallObjectScale, kBallObjectScale, &modelViewMatrix.data[0]);
            SampleApplicationUtils::multiplyMatrix(&vapp.projectionMatrix.data[0], &modelViewMatrix.data[0], &modelViewProjection.data[0]);
            
            // Set the vertex attribute pointers
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)&sphereVerts[0]);
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)&sphereNormals[0]);
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)&sphereTexCoords[0]);
            
            // Bind the texture and draw the geometry
            glBindTexture(GL_TEXTURE_2D, [augmentationTexture[BALL_TEXTURE_INDEX] textureID]);
            
            glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE, (const GLfloat*)&modelViewProjection.data[0]);
            
            glDrawArrays(GL_TRIANGLES, 0, sphereNumVerts);
            // --- End of soccer ball augmentation ---
            
            // Check for GL error
            SampleApplicationUtils::checkGlError("EAGLView renderFrameQCAR");
            */
            
            modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(result->getPose());
            
            pen2world.at<float>(0, 0) = modelViewMatrix.data[0];
            pen2world.at<float>(1, 0) = modelViewMatrix.data[1];
            pen2world.at<float>(2, 0) = modelViewMatrix.data[2];
            pen2world.at<float>(3, 0) = modelViewMatrix.data[3];
            pen2world.at<float>(0, 1) = modelViewMatrix.data[4];
            pen2world.at<float>(1, 1) = modelViewMatrix.data[5];
            pen2world.at<float>(2, 1) = modelViewMatrix.data[6];
            pen2world.at<float>(3, 1) = modelViewMatrix.data[7];
            pen2world.at<float>(0, 2) = modelViewMatrix.data[8];
            pen2world.at<float>(1, 2) = modelViewMatrix.data[9];
            pen2world.at<float>(2, 2) = modelViewMatrix.data[10];
            pen2world.at<float>(3, 2) = modelViewMatrix.data[11];
            pen2world.at<float>(0, 3) = modelViewMatrix.data[12];
            pen2world.at<float>(1, 3) = modelViewMatrix.data[13];
            pen2world.at<float>(2, 3) = modelViewMatrix.data[14];
            pen2world.at<float>(3, 3) = modelViewMatrix.data[15];
            
            SampleApplicationUtils::translatePoseMatrix(-kCylinderTopDiameter / 2.0f + 10.0f, 0.0f, 0.0f, &modelViewMatrix.data[0]);

            SampleApplicationUtils::scalePoseMatrix(kCylinderHeight / 2.5f, kCylinderHeight / 2.5f, kCylinderHeight / 2.5f, &modelViewMatrix.data[0]);
            

            SampleApplicationUtils::rotatePoseMatrix(90.0f, 1.0f, 0.0f, 0.0f, &modelViewMatrix.data[0]);
            
            SampleApplicationUtils::multiplyMatrix(&vapp.projectionMatrix.data[0], &modelViewMatrix.data[0], &modelViewProjection.data[0]);

            // Pen
            typedef struct _vertexStruct
            {
                GLfloat texcoord[2];
                GLfloat normal[3];
                GLfloat position[3];
            } vertexStruct;
            
            glEnableVertexAttribArray(vertexHandle);
            glEnableVertexAttribArray(normalHandle);
            glEnableVertexAttribArray(textureCoordHandle);
            
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, sizeof(vertexStruct), (const GLvoid*)&capsule_vertex[0][5]);
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, sizeof(vertexStruct), (const GLvoid*)&capsule_vertex[0][0]);
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)&capsule_vertex[0][2]);
            
            glActiveTexture(GL_TEXTURE0);
            
            glBindTexture(GL_TEXTURE_2D, augmentationTexture[3].textureID);
            glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE, (const GLfloat*)&modelViewProjection.data[0]);
            glUniform1i(texSampler2DHandle, 0 /*GL_TEXTURE0*/);
            
            glDrawElements(GL_TRIANGLES, capsule_polygoncount*3, GL_UNSIGNED_SHORT, (const GLvoid*)capsule_index);

            
            flagDetectBoth++;
        }
        else // Stones and Chips
        {
            QCAR::Matrix44F modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(result->getPose());
            targetModelViewMatrix = modelViewMatrix;
            
            // OpenGL 2
            QCAR::Matrix44F modelViewProjection;
            
            target2world.at<float>(0, 0) = modelViewMatrix.data[0];
            target2world.at<float>(1, 0) = modelViewMatrix.data[1];
            target2world.at<float>(2, 0) = modelViewMatrix.data[2];
            target2world.at<float>(3, 0) = modelViewMatrix.data[3];
            target2world.at<float>(0, 1) = modelViewMatrix.data[4];
            target2world.at<float>(1, 1) = modelViewMatrix.data[5];
            target2world.at<float>(2, 1) = modelViewMatrix.data[6];
            target2world.at<float>(3, 1) = modelViewMatrix.data[7];
            target2world.at<float>(0, 2) = modelViewMatrix.data[8];
            target2world.at<float>(1, 2) = modelViewMatrix.data[9];
            target2world.at<float>(2, 2) = modelViewMatrix.data[10];
            target2world.at<float>(3, 2) = modelViewMatrix.data[11];
            target2world.at<float>(0, 3) = modelViewMatrix.data[12];
            target2world.at<float>(1, 3) = modelViewMatrix.data[13];
            target2world.at<float>(2, 3) = modelViewMatrix.data[14];
            target2world.at<float>(3, 3) = modelViewMatrix.data[15];

            SampleApplicationUtils::translatePoseMatrix(0.0f, 0.0f, kObjectScaleNormal / 2.0, &modelViewMatrix.data[0]);
            SampleApplicationUtils::scalePoseMatrix(kObjectScaleNormal, kObjectScaleNormal, kObjectScaleNormal, &modelViewMatrix.data[0]);
            
            SampleApplicationUtils::multiplyMatrix(&vapp.projectionMatrix.data[0], &modelViewMatrix.data[0], &modelViewProjection.data[0]);
            

            typedef struct _vertexStruct
            {
                GLfloat texcoord[2];
                GLfloat normal[3];
                GLfloat position[3];
            } vertexStruct;

            glEnableVertexAttribArray(vertexHandle);
            glEnableVertexAttribArray(normalHandle);
            glEnableVertexAttribArray(textureCoordHandle);

            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, sizeof(vertexStruct), (const GLvoid*)&cube_vertex[0][5]);
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, sizeof(vertexStruct), (const GLvoid*)&cube_vertex[0][0]);
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)&cube_vertex[0][2]);
            
            glActiveTexture(GL_TEXTURE0);
            
            glBindTexture(GL_TEXTURE_2D, augmentationTexture[3].textureID);
            glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE, (const GLfloat*)&modelViewProjection.data[0]);
            glUniform1i(texSampler2DHandle, 0 /*GL_TEXTURE0*/);

            glDrawElements(GL_TRIANGLES, cube_polygoncount*3, GL_UNSIGNED_SHORT, (const GLvoid*)cube_index);
            
            flagDetectBoth++;
        }
        
        if (flagDetectBoth > 1)
        {
            pentipMat = target2world.inv() * pen2world * pentipMat;
            NSArray *pentipOnTarget = [NSArray arrayWithObjects:[NSNumber numberWithFloat:pentipMat.at<float>(0, 0)], [NSNumber numberWithFloat:pentipMat.at<float>(1, 0)], [NSNumber numberWithFloat:pentipMat.at<float>(2, 0)], nil];
            [drawLine addObject:pentipOnTarget];
            
            NSLog(@"%lf, %lf, %lf", [[pentipOnTarget objectAtIndex:0] floatValue], [[pentipOnTarget objectAtIndex:1] floatValue], [[pentipOnTarget objectAtIndex:2] floatValue]);
        }
        
        if (targetIndex != 0)
        {
        // OpenGL 2
        QCAR::Matrix44F modelViewProjection;
            
        SampleApplicationUtils::multiplyMatrix(&vapp.projectionMatrix.data[0], &targetModelViewMatrix.data[0], &modelViewProjection.data[0]);
        
        glEnableVertexAttribArray(vertexHandle);
        
        GLfloat *verteces = (GLfloat*)malloc([drawLine count] * 3 * sizeof(GLfloat));
        for (int i = 0; i < [drawLine count]; i++)
        {
            verteces[i * 3 + 0] = [[[drawLine objectAtIndex:i] objectAtIndex:0] floatValue];
            verteces[i * 3 + 1] = [[[drawLine objectAtIndex:i] objectAtIndex:1] floatValue];
            verteces[i * 3 + 2] = [[[drawLine objectAtIndex:i] objectAtIndex:2] floatValue];
        }
            
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)&verteces[0]);
            
            glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE, (const GLfloat*)&modelViewProjection.data[0]);
            glLineWidth(4);
            glDrawArrays(GL_LINES, 0, (GLint)[drawLine count]);
        }
        
    }
    
    glDisable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    
    glDisableVertexAttribArray(vertexHandle);
    glDisableVertexAttribArray(normalHandle);
    glDisableVertexAttribArray(textureCoordHandle);

    // End QCAR rendering for this frame
    QCAR::Renderer::getInstance().end();
    
    [self presentFramebuffer];

}

//------------------------------------------------------------------------------
#pragma mark - OpenGL ES management

- (void)initShaders
{
    shaderProgramID = [SampleApplicationShaderUtils createProgramWithVertexShaderFileName:@"Simple.vertsh"
                                                   fragmentShaderFileName:@"Simple.fragsh"];

    if (0 < shaderProgramID) {
        vertexHandle = glGetAttribLocation(shaderProgramID, "vertexPosition");
        normalHandle = glGetAttribLocation(shaderProgramID, "vertexNormal");
        textureCoordHandle = glGetAttribLocation(shaderProgramID, "vertexTexCoord");
        mvpMatrixHandle = glGetUniformLocation(shaderProgramID, "modelViewProjectionMatrix");
        texSampler2DHandle  = glGetUniformLocation(shaderProgramID,"texSampler2D");
    }
    else {
        NSLog(@"Could not initialise augmentation shader");
    }
}


- (void)createFramebuffer
{
    if (context) {
        // Create default framebuffer object
        glGenFramebuffers(1, &defaultFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        
        // Create colour renderbuffer and allocate backing store
        glGenRenderbuffers(1, &colorRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        
        // Allocate the renderbuffer's storage (shared with the drawable object)
        [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
        GLint framebufferWidth;
        GLint framebufferHeight;
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &framebufferWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &framebufferHeight);
        
        // Create the depth render buffer and allocate storage
        glGenRenderbuffers(1, &depthRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, framebufferWidth, framebufferHeight);
        
        // Attach colour and depth render buffers to the frame buffer
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
        
        // Leave the colour render buffer bound so future rendering operations will act on it
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    }
}


- (void)deleteFramebuffer
{
    if (context) {
        [EAGLContext setCurrentContext:context];
        
        if (defaultFramebuffer) {
            glDeleteFramebuffers(1, &defaultFramebuffer);
            defaultFramebuffer = 0;
        }
        
        if (colorRenderbuffer) {
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            colorRenderbuffer = 0;
        }
        
        if (depthRenderbuffer) {
            glDeleteRenderbuffers(1, &depthRenderbuffer);
            depthRenderbuffer = 0;
        }
    }
}


- (void)setFramebuffer
{
    // The EAGLContext must be set for each thread that wishes to use it.  Set
    // it the first time this method is called (on the render thread)
    if (context != [EAGLContext currentContext]) {
        [EAGLContext setCurrentContext:context];
    }
    
    if (!defaultFramebuffer) {
        // Perform on the main thread to ensure safe memory allocation for the
        // shared buffer.  Block until the operation is complete to prevent
        // simultaneous access to the OpenGL context
        [self performSelectorOnMainThread:@selector(createFramebuffer) withObject:self waitUntilDone:YES];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
}


- (BOOL)presentFramebuffer
{
    // setFramebuffer must have been called before presentFramebuffer, therefore
    // we know the context is valid and has been set for this (render) thread
    
    // Bind the colour render buffer and present it
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    
    return [context presentRenderbuffer:GL_RENDERBUFFER];
}


//------

//------------------------------------------------------------------------------
#pragma mark - Augmentation animation

- (void)animateObject:(QCAR::Matrix44F&)modelViewMatrix
{
    static float rotateBowlAngle = 0.0f;
    static double prevTime = [self getCurrentTime];
    double time = [self getCurrentTime];             // Get real time difference
    float dt = (float)(time-prevTime);          // from frame to frame
    
    rotateBowlAngle += dt * 180.0f/3.1415f;     // Animate angle based on time
    
    SampleApplicationUtils::rotatePoseMatrix(rotateBowlAngle, 0.0f, 0.0f, 1.0f, &modelViewMatrix.data[0]);
    
    prevTime = time;
}


- (double)getCurrentTime
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec / 1000000.0;
}

- (void)clearDrawLines
{
//    drawLine = [NSMutableArray array];
    drawLines = [NSMutableArray array];
}

@end

