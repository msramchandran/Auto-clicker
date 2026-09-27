package com.example.autoclicker

import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.View
import kotlin.math.abs

class CropBoxView(context: Context) : View(context) {

    // Default crop box in center of screen
    var cropRect = RectF(100f, 300f, 800f, 700f)
        private set

    private val paintDim = Paint().apply { color = Color.parseColor("#99000000") }
    private val paintBorder = Paint().apply {
        color = Color.parseColor("#00C853") // Green
        style = Paint.Style.STROKE
        strokeWidth = 6f
    }
    private val paintCorner = Paint().apply {
        color = Color.parseColor("#FF9800") // Orange
        style = Paint.Style.FILL
    }
    private val paintText = Paint().apply {
        color = Color.WHITE
        textSize = 40f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.DEFAULT_BOLD
        setShadowLayer(5f, 0f, 0f, Color.BLACK)
    }

    private val cornerRadius = 35f
    private val touchArea = 100f

    private var activeCorner: Int = -1 // 0=TL, 1=TR, 2=BR, 3=BL, 4=CENTER
    private var lastX = 0f
    private var lastY = 0f

    fun setInitialRect(rect: RectF) {
        if (rect.width() > 0 && rect.height() > 0) {
            cropRect = rect
            invalidate()
        }
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        // If crop box is out of bounds or too big, reset it
        if (cropRect.right > w || cropRect.bottom > h || cropRect.width() <= 0) {
            val cx = w / 2f
            val cy = h / 2f
            cropRect = RectF(cx - 300f, cy - 200f, cx + 300f, cy + 200f)
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        
        // Draw dim background outside the crop box
        val path = Path()
        path.addRect(0f, 0f, width.toFloat(), height.toFloat(), Path.Direction.CW)
        path.addRect(cropRect, Path.Direction.CCW)
        canvas.drawPath(path, paintDim)

        // Draw border
        canvas.drawRect(cropRect, paintBorder)

        // Draw corners
        canvas.drawCircle(cropRect.left, cropRect.top, cornerRadius, paintCorner)
        canvas.drawCircle(cropRect.right, cropRect.top, cornerRadius, paintCorner)
        canvas.drawCircle(cropRect.right, cropRect.bottom, cornerRadius, paintCorner)
        canvas.drawCircle(cropRect.left, cropRect.bottom, cornerRadius, paintCorner)

        // Draw helper text inside
        canvas.drawText("Target Zone", cropRect.centerX(), cropRect.centerY(), paintText)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val x = event.x
        val y = event.y

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                activeCorner = getTouchedCorner(x, y)
                if (activeCorner != -1) {
                    lastX = x
                    lastY = y
                    return true
                }
                return false
            }
            MotionEvent.ACTION_MOVE -> {
                if (activeCorner == -1) return false
                val dx = x - lastX
                val dy = y - lastY
                
                when (activeCorner) {
                    0 -> { cropRect.left += dx; cropRect.top += dy } // Top-Left
                    1 -> { cropRect.right += dx; cropRect.top += dy } // Top-Right
                    2 -> { cropRect.right += dx; cropRect.bottom += dy } // Bottom-Right
                    3 -> { cropRect.left += dx; cropRect.bottom += dy } // Bottom-Left
                    4 -> { cropRect.offset(dx, dy) } // Center Move
                }

                // Constrain minimum size
                val minSize = 150f
                if (cropRect.width() < minSize) {
                    if (activeCorner == 0 || activeCorner == 3) cropRect.left = cropRect.right - minSize
                    else cropRect.right = cropRect.left + minSize
                }
                if (cropRect.height() < minSize) {
                    if (activeCorner == 0 || activeCorner == 1) cropRect.top = cropRect.bottom - minSize
                    else cropRect.bottom = cropRect.top + minSize
                }

                // Constrain to screen bounds
                if (cropRect.left < 0) cropRect.left = 0f
                if (cropRect.top < 0) cropRect.top = 0f
                if (cropRect.right > width) cropRect.right = width.toFloat()
                if (cropRect.bottom > height) cropRect.bottom = height.toFloat()

                lastX = x
                lastY = y
                invalidate()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                activeCorner = -1
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun getTouchedCorner(x: Float, y: Float): Int {
        if (abs(x - cropRect.left) < touchArea && abs(y - cropRect.top) < touchArea) return 0
        if (abs(x - cropRect.right) < touchArea && abs(y - cropRect.top) < touchArea) return 1
        if (abs(x - cropRect.right) < touchArea && abs(y - cropRect.bottom) < touchArea) return 2
        if (abs(x - cropRect.left) < touchArea && abs(y - cropRect.bottom) < touchArea) return 3
        if (cropRect.contains(x, y)) return 4
        return -1
    }
}
